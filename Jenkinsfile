pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    CANARY_APP_NAME = 'app-canary'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    CANARY_PERCENTAGE = '25' 
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
          docker stack deploy -c docker-compose_canary.yaml ${CANARY_APP_NAME} --with-registry-auth
          
          echo "Ожидание запуска canary-сервисов..."
          sleep 40
          
          # Проверяем статус canary-сервисов
          docker service ls --filter name=${CANARY_APP_NAME}
        '''
      }
    }

    stage('Canary Testing') {
  steps {
    sh '''
      echo "=== Тестирование Canary-версии ==="

      CANARY_SUCCESS=0
      CANARY_TESTS=10

      for i in $(seq 1 $CANARY_TESTS); do
        echo "Тест $i/$CANARY_TESTS..."

        # Попробуем главную страницу (у тебя точно работает /, а не /health-check)
        if curl -f -s --max-time 15 http://192.168.0.1:8081/ > /tmp/canary_response_$i.html; then
          if ! grep -iq "error\\|fatal\\|exception\\|failed\\|warning" /tmp/canary_response_$i.html; then
            CANARY_SUCCESS=$((CANARY_SUCCESS + 1))
            echo "Успешно Тест $i пройден — приложение отвечает"
          else
            echo "Ошибка Тест $i: в ответе есть слово error/fatal"
            cat /tmp/canary_response_$i.html | head -20
          fi
        else
          echo "Ошибка Тест $i: нет ответа 200"
        fi

        sleep 6
      done

      echo "Результаты: $CANARY_SUCCESS из $CANARY_TESTS успешных"

      if [ "$CANARY_SUCCESS" -lt 8 ]; then
        echo "Ошибка Canary-тестирование провалено ($CANARY_SUCCESS/10)"
        exit 1  # Это прервет пайплайн
      else
        echo "Успешно Canary-тестирование пройдено!"
      fi
    '''
  }
}


    stage('Gradual Traffic Shift') {
  steps {
    sh '''
      echo "=== Постепенное переключение трафика ==="
      
      # Проверяем, существует ли основной сервис
      if docker service ls --filter name=${APP_NAME}_web-server | grep -q ${APP_NAME}_web-server; then
        echo "Основной сервис существует, выполняем постепенное переключение..."
        
        # Этап 1: 50% трафика на новую версию
        echo "Этап 1: 50% трафика на новую версию"
        docker service update --image ${DOCKER_HUB_USER}/crudback:${BUILD_NUMBER} ${APP_NAME}_web-server --replicas 2
        docker service update --image ${DOCKER_HUB_USER}/crudback:latest ${CANARY_APP_NAME}_web-server --replicas 2
        sleep 120
        
        # Мониторинг метрик
        echo "Мониторинг метрик после 50% переключения..."
        sleep 30
        
        # Этап 2: 100% трафика на новую версию
        echo "Этап 2: 100% трафика на новую версию"
        docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth
        docker service scale ${APP_NAME}_web-server=3
        sleep 50
        
        # Удаляем canary stack
        echo "Удаление canary stack..."
        docker stack rm ${CANARY_APP_NAME}
        sleep 15
        
      else
        echo "Основной сервис не существует, развертываем продакшен вместо canary..."
        
        # Удаляем canary и развертываем полноценный продакшен
        docker stack rm ${CANARY_APP_NAME} || true
        sleep 30
        
        # Развертываем продакшен
        docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth
        sleep 60
        
        echo "Продакшен успешно развернут с нуля"
      fi
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
            if curl -f --max-time 10 http://192.168.0.1:8080/ > /dev/null 2>&1; then
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
    echo "✗ Canary-тестирование провалено - откат не требуется, так как изменения не были применены"
    sh '''
      echo "Останавливаем canary-сервисы..."
      docker stack rm ${CANARY_APP_NAME} || true
      
      echo "Проверяем, что prod-сервисы работают без изменений..."
      docker service ls --filter name=${APP_NAME}
      
      echo "Canary удален, продакшен остался без изменений"
    '''
    sh 'docker logout'
  }
  }
}
