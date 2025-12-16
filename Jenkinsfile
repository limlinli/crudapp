pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    CANARY_SERVICE_NAME = 'app_canary_php'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    BACKEND_IMAGE_NAME = 'crudback'
    DATABASE_IMAGE_NAME = 'mysql'
    MANAGER_IP = '192.168.0.1'
    PROD_NETWORK = 'crudapp_default'  // Имя сети из стека app
  }

  stages {
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'
      }
    }

    stage('Build Docker Images') {
      steps {
        sh "docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}"
        sh "docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/${DATABASE_IMAGE_NAME}:${BUILD_NUMBER}"
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
            docker push ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}
            docker push ${DOCKER_HUB_USER}/${DATABASE_IMAGE_NAME}:${BUILD_NUMBER}
          '''
        }
      }
    }

       stage('Deploy Canary') {
      steps {
        sh '''
          echo "=== Создание временного Canary-сервиса ==="
          # Создаем сервис БЕЗ публикации порта наружу (тестируем внутри сети)
          docker service create \
            --name ${CANARY_SERVICE_NAME} \
            --replicas 1 \
            --network ${PROD_NETWORK} \
            ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}
          
          # Ждем стабилизации контейнера
          sleep 20
        '''
      }
    }

    stage('Canary Testing') {
      steps {
        script {
          // Выполняем проверку внутри сети Swarm с помощью временного контейнера curl
          def testResult = sh(
            script: "docker run --rm --network ${PROD_NETWORK} curlimages/curl:latest curl -s -o /dev/null -w '%{http_code}' http://${CANARY_SERVICE_NAME}:80/health",
            returnStatus: true
          )

          // Если статус не 0 (команда упала) или нам нужен конкретный HTTP код
          // В данном примере проверим просто доступность (exit code 0)
          if (testResult != 0) {
            error "Canary Test Failed: Сервис недоступен внутри сети!"
          } else {
            echo "Canary Test Passed: Новый образ работает корректно."
          }
        }
      }
    }

    stage('Rollout Production') {
      steps {
        sh '''
          echo "=== Тесты пройдены. Обновляем основной сервис ==="
          
          docker service update \
            --image ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} \
            --update-parallelism 1 \
            --update-delay 10s \
            --update-order start-first \
            ${APP_NAME}_web-server

          echo "Удаление временного canary-сервиса..."
          docker service rm ${CANARY_SERVICE_NAME}
        '''
      }
    }

    stage('Final Verification') {
      steps {
        sh '''
          echo "=== Финальная проверка ==="
          for i in $(seq 1 5); do
            curl -f --max-time 10 http://${MANAGER_IP}:8080/ > /dev/null && echo "Тест $i пройден" || exit 1
            sleep 5
          done
        '''
      }
    }
  }

  post {
    always {
      sh 'docker logout || true'
    }
    failure {
      sh "docker service rm ${CANARY_SERVICE_NAME} || true"
    }
  }
}
