pipeline {
  agent { 
    label 'docker-agent' 
  }
  
  triggers {
    githubPush()
  }
  
  environment {
    APP_NAME = 'app'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    MANAGER_IP = '192.168.0.1'
  }
  
  stages {
    stage('Checkout') {
      steps { 
        git url: "${GIT_REPO}", branch: 'main' 
      }
    }

    stage('Build Docker Images') {
      steps {
        script {
          sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/crudback:latest'
          sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/mysql:latest'
        }
      }
    }

    stage('Test') {
      steps {
        sh '''
          echo "Проверка доступности приложения"
          sleep 10
          curl -f http://${MANAGER_IP}:8080 > /dev/null || exit 1
          echo "Тест пройден успешно"
        '''
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'docker-hub-credentials', 
          usernameVariable: 'DOCKER_USER', 
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
            docker push ${DOCKER_HUB_USER}/crudback:latest
            docker push ${DOCKER_HUB_USER}/mysql:latest
          '''
        }
      }
    }

    stage('Deploy to Swarm') {
      steps {
        sh '''
          docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth
          echo "Деплой запущен"
          sleep 30
          echo "Статус сервисов:"
          docker service ls
        '''
      }
    }
  }

  post {
    always { 
      sh 'docker logout'
      cleanWs()  // Очистка workspace
    }
    success {
      echo 'Pipeline выполнен успешно!'
    }
    failure {
      echo 'Pipeline завершился с ошибкой'
      // Можно добавить уведомления
    }
  }
}
