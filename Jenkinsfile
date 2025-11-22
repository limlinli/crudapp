pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    CANARY_APP_NAME = 'app-canary'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    CANARY_PERCENTAGE = '25' // 25% трафика на канарейку
    BUILD_NUMBER = env.BUILD_NUMBER  // Автоматический номер сборки
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
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            docker login -u $DOCKER_USER -p $DOCKER_PASS
            docker push ${DOCKER_HUB_USER}/crudback:${BUILD_NUMBER}
            docker push ${DOCKER_HUB_USER}/mysql:${BUILD_NUMBER}
          '''
        }
      }
    }

    stage('Deploy Canary') {
      steps {
        sh '''
          echo "Развертывание Canary (25% трафика)..."
          docker stack deploy -c docker-compose_canary.yaml ${CANARY_APP_NAME}
          sleep 30  # Ждём запуска
          docker service ls --filter name=${CANARY_APP_NAME}
        '''
      }
    }

    stage('Canary Testing') {
      steps {
        sh '''
          echo "Тестирование Canary..."
          for i in $(seq 1 10); do
            if curl -f http://192.168.0.1:8081; then  # Порт canary
              echo "Тест $i: OK"
            else
              echo "Тест $i: Ошибка"
              exit 1
            fi
            sleep 5
          done
          echo "Canary тест пройден!"
        '''
      }
    }

    stage('Gradual Traffic Shift') {
      steps {
        sh '''
          echo "Переключение трафика: 50%..."
          docker service scale ${APP_NAME}_web-server=2
          docker service scale ${CANARY_APP_NAME}_php=2
          sleep 60  # Мониторинг
          
          echo "Переключение трафика: 100%..."
          docker stack rm ${APP_NAME}  # Удаляем старый
          docker stack deploy -c docker-compose.yaml ${APP_NAME}  # Полный деплой новой версии
          sleep 30
        '''
      }
    }

    stage('Final Verification') {
      steps {
        sh '''
          echo "Финальная проверка..."
          docker service ls
          curl -f http://192.168.0.1:8080  # Порт прод
        '''
      }
    }
  }

  post {
    success { echo "Canary деплой успешен!" }
    failure {
      echo "Откат..."
      sh 'docker stack rm ${CANARY_APP_NAME}'  
    }
    always { sh 'docker logout' }
  }
}
