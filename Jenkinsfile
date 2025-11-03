pipeline {
  agent { label 'docker-agent' }
  triggers {
        githubPush()
    }
  environment {
    APP_NAME = 'app'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    MANAGER_IP = '192.168.0.1'  // ← ваш IP manager-ноды
  }
  stages {
    stage('Checkout') {
      steps { git url: "${GIT_REPO}", branch: 'main' }
    }

    stage('Build Docker Images') {
      steps {
        sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/crudback:latest'
        sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/mysql:latest'
      }
    }

    stage('Test') {
      steps {
        sh '''
          echo "Проверка: ${MANAGER_IP}:8080"
          curl -f http://${MANAGER_IP}:8080 > /dev/null || exit 1
          echo "Тест пройден"
        '''
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
          sh 'docker push ${DOCKER_HUB_USER}/crudback:latest'
          sh 'docker push ${DOCKER_HUB_USER}/mysql:latest'
        }
      }
    }

    stage('Deploy to Swarm (Canary)') {
      steps {
        sh '''
          docker stack deploy -c docker-compose.yaml ${APP_NAME}
          echo "Canary-деплой запущен"
          sleep 30
          docker service ls
        '''
      }
    }
  }

  post {
    always { sh 'docker logout' }
  }
}
