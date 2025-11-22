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
            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
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
          
          # Развертывание canary stack с 1 репликой
          docker stack deploy -c docker-compose_canary.yaml ${CANARY_APP_NAME} --with-registry-auth
          
          echo "Ожидание запуска canary-сервисов..."
          sleep 30
          
          # Проверка статуса
          docker service ls --filter name=${CANARY_APP_NAME}
        '''
      }
    }

    stage('Canary Testing') {
      steps {
        sh '''
          echo "=== Тестирование Canary-версии ==="
          
          CANARY_SUCCESS=0
          TESTS=10
          
          for i in $(seq 1 $TESTS); do
            echo "Тест $i/$TESTS..."
            if curl -f --max-time 10 http://192.168.0.1:8081/index.php; then
              ((CANARY_SUCCESS++))
              echo "✓ Тест $i пройден"
            else
              echo "✗ Тест $i: ошибка"
            fi
            sleep 5
          done
          
          echo "Результаты: $CANARY_SUCCESS/$TESTS успешных"
          
          if [ $CANARY_SUCCESS -lt $((TESTS * 80 / 100)) ]; then
            echo "✗ Canary провален"
            exit 1
          fi
          
          echo "✓ Canary успешен"
        '''
      }
    }

    stage('Gradual Traffic Shift') {
      steps {
        sh '''
          echo "=== Постепенное переключение трафика ==="
          
          # Этап 1: 50% трафика на новую версию
          echo "Этап 1: 50% трафика"
          docker service update --replicas 2 ${APP_NAME}_web-server --image ${DOCKER_HUB_USER}/crudback:${BUILD_NUMBER}
          docker service update --replicas 1 ${CANARY_APP_NAME}_php
          sleep 60
          
          # Мониторинг
          docker service ls
          
          # Этап 2: 100% трафика на новую версию
          echo "Этап 2: 100% трафика"
          docker service update --replicas 2 ${APP_NAME}_web-server --image ${DOCKER_HUB_USER}/crudback:${BUILD_NUMBER}
          docker stack rm ${CANARY_APP_NAME}
          sleep 30
        '''
      }
    }

    stage('Final Verification') {
      steps {
        sh '''
          echo "=== Финальная проверка ==="
          
          # Проверка сервисов
          docker service ls --filter name=${APP_NAME}
          
          # Финальные тесты
          for i in $(seq 1 5); do
            curl -f --max-time 10 http://192.168.0.1:8080/health-check || exit 1
            echo "✓ Финальный тест $i пройден"
            sleep 5
          done
          
          echo "✓ Всё OK"
        '''
      }
    }
  }

  post {
    success {
      echo "✓ Canary-деплой успешен"
      sh 'docker logout'
      sh 'docker image prune -f'
    }
    failure {
      echo "✗ Ошибка — откат"
      sh 'docker stack rm ${CANARY_APP_NAME} || true'
      sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth'
      sh 'docker logout'
    }
  }
}
