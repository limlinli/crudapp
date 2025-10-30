pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
  }
  stages {
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'
      }
    }
    stage('Build Docker Images') {
      steps {
        sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/crudback:latest'
        sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/mysql:latest'
      }
    }
    stage('Test') {
      steps {
        // Очистка перед тестом
        sh 'docker-compose down --rmi local --volumes --remove-orphans || true'
        
        // Запуск тестового окружения
        sh 'docker-compose up -d'
        sh 'sleep 20'
        
        // Проверка веб-сервера (имя контейнера: app_web-server_1)
        sh 'docker exec $(docker ps -q -f name=app_web-server) curl -f http://localhost || exit 1'
        
        // Очистка после теста
        sh 'docker-compose down --rmi local --volumes --remove-orphans'
      }
    }
    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
          sh 'docker push ${DOCKER_HUB_USER}/crudback:latest'
          sh 'docker push ${DOCKER_HUB_USER}/mysql:latest'
        }
      }
    }
    stage('Deploy to Swarm') {
      steps {
        sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'
        sh 'sleep 30'
        sh 'docker service ls'
      }
    }
  }
  post {
    always {
      sh 'docker logout || true'
    }
  }
}
