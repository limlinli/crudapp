pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    CANARY_APP_NAME = 'app-canary'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    CANARY_PERCENTAGE = '25' // 25% трафика на канарейку
  }

  stages {
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'
      }
    }

    stage('Build Docker Images') {
      steps {
        sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/crudback:${BUILD_NUMBER}'
        sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/mysql:${BUILD_NUMBER}'
        sh 'docker tag ${DOCKER_HUB_USER}/crudback:${BUILD_NUMBER} ${DOCKER_HUB_USER}/crudback:latest'
        sh 'docker tag ${DOCKER_HUB_USER}/mysql:${BUILD_NUMBER} ${DOCKER_HUB_USER}/mysql:latest'
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            docker login -u $DOCKER_USER -p $DOCKER_PASS
            docker push ${DOCKER_HUB_USER}/crudback:${BUILD_NUMBER}
            docker push ${DOCKER_HUB_USER}/mysql:${BUILD_NUMBER}
            docker push ${DOCKER_HUB_USER}/crudback:latest
            docker push ${DOCKER_HUB_USER}/mysql:latest
          '''
        }
      }
    }

    stage('Deploy Canary') {
      steps {
        sh '''
          echo "=== Развертывание Canary (${CANARY_PERCENTAGE}% трафика) ==="
          
          # Создаем canary stack с ограниченным количеством реплик
          docker stack deploy -c docker-compose.canary.yaml ${CANARY_APP_NAME} --with-registry-auth
          
          echo "Ожидание запуска canary-сервисов..."
          sleep 30
          
          # Проверяем статус canary-сервисов
          docker service ls --filter name=${CANARY_APP_NAME}
        '''
      }
    }

    stage('Canary Testing') {
      steps {
        sh '''
          echo "=== Тестирование Canary-версии ==="
          
          # Тестируем канарейку
          CANARY_SUCCESS=0
          CANARY_TESTS=10
          
          for i in $(seq 1 $CANARY_TESTS); do
            echo "Тест $i/$CANARY_TESTS..."
            if curl -f --max-time 10 http://192.168.0.1:8081/health-check > /tmp/canary_response_$i.html 2>/dev/null; then
              if ! grep -iq "error\\|fail\\|exception" /tmp/canary_response_$i.html; then
                ((CANARY_SUCCESS++))
                echo "✓ Тест $i пройден"
              else
                echo "✗ Тест $i: обнаружены ошибки в ответе"
              fi
            else
              echo "✗ Тест $i: HTTP ошибка"
            fi
            sleep 5
          done
          
          echo "Результаты тестирования: $CANARY_SUCCESS/$CANARY_TESTS успешных тестов"
          
          # Требуем минимум 80% успешных тестов
          if [ $CANARY_SUCCESS -lt $((CANARY_TESTS * 80 / 100)) ]; then
            echo "✗ Canary-тестирование провалено"
            exit 1
          fi
          
          echo "✓ Canary-тестирование успешно пройдено"
        '''
      }
    }

    stage('Gradual Traffic Shift') {
      steps {
        sh '''
          echo "=== Постепенное переключение трафика ==="
          
          # Этап 1: 50% трафика на новую версию
          echo "Этап 1: 50% трафика на новую версию"
          docker service update --image ${DOCKER_HUB_USER}/crudback:${BUILD_NUMBER} ${APP_NAME}_web-server --replicas 4
          docker service update --image ${DOCKER_HUB_USER}/crudback:latest ${CANARY_APP_NAME}_web-server --replicas 4
          sleep 60
          
          # Мониторинг метрик
          echo "Мониторинг метрик после 50% переключения..."
          sleep 30
          
          # Этап 2: 100% трафика на новую версию
          echo "Этап 2: 100% трафика на новую версию"
          docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth
          docker service scale ${APP_NAME}_web-server=8
          sleep 30
          
          # Удаляем canary stack
          echo "Удаление canary stack..."
          docker stack rm ${CANARY_APP_NAME}
          sleep 15
        '''
      }
    }

    stage('Final Verification') {
      steps {
        sh '''
          echo "=== Финальная проверка ==="
          
          # Проверяем, что все сервисы работают
          docker service ls --filter name=${APP_NAME}
          
          # Финальное тестирование
          for i in $(seq 1 5); do
            echo "Финальный тест $i/5..."
            if curl -f --max-time 10 http://192.168.0.1:8080/health-check > /dev/null 2>&1; then
              echo "✓ Финальный тест $i пройден"
            else
              echo "✗ Финальный тест $i не пройден"
              exit 1
            fi
            sleep 5
          done
          
          echo "✓ Все проверки пройдены успешно"
        '''
      }
    }
  }

  post {
    success {
      echo "✓ Canary-деплой успешно завершен"
      sh 'docker logout'
      sh '''
        # Очистка старых образов
        docker image prune -f
      '''
    }
    failure {
      echo "✗ Ошибка в canary-деплое — откат на стабильную версию"
      sh '''
        echo "Выполняем откат..."
        
        # Останавливаем canary
        docker stack rm ${CANARY_APP_NAME} || true
        
        # Восстанавливаем стабильную версию
        docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth
        docker service scale ${APP_NAME}_web-server=8
        
        echo "Откат завершен"
      '''
      sh 'docker logout'
    }
  }
}
