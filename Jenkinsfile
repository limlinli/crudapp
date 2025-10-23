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
        sh 'docker-compose -f docker-compose-test.yaml down -v || true'  // -v удаляет volume для свежей БД
        sh 'docker-compose -f docker-compose-test.yaml up -d'
        sh 'sleep 40'  // Увеличено для инициализации MySQL и dump
        sh 'docker exec crud-ci-cd-web-server-1 curl -s http://localhost:80 | grep -q "Список товаров"'
        sh 'docker exec crud-ci-cd-web-server-1 curl -s http://localhost:80 | grep -q "asd"'  // Проверка данных из БД
        sh 'docker-compose -f docker-compose-test.yaml down -v || true'
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
    stage('Deploy to Swarm with Canary') {
      steps {
        sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'
        sh 'sleep 30'
        sh 'docker service update --image ${DOCKER_HUB_USER}/crudback:latest --update-delay 10s --update-parallelism 1 ${APP_NAME}_web-server'
        sh 'docker service update --image ${DOCKER_HUB_USER}/mysql:latest --update-delay 10s --update-parallelism 1 ${APP_NAME}_db'
        sh 'sleep 30'
        sh 'docker service ls'
      }
    }
  }
  post {
    always {
      sh 'docker logout'
    }
  }
}
