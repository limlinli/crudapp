pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    DB_USER = 'root'
    DB_PASS = 'secret'  // Убедитесь, что этот пароль совпадает с docker-compose-test.yaml
    DB_NAME = 'lena'
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
        sh 'docker-compose -f docker-compose-test.yaml -p test-app up -d'
        sh 'sleep 30'  // Ожидание инициализации
        sh 'docker exec test-app-web-server-1 curl -s -o /dev/null http://localhost:80 || exit 1'  // Проверка веб-сервера
        sh 'docker exec test-app-phpmyadmin-1 curl -s -o /dev/null http://localhost:80 || exit 1'  // Проверка phpMyAdmin
        // Проверка подключения к базе данных
        sh '''
  docker exec test-app-web-server-1 php -r "try { \$pdo = new PDO(\\'mysql:host=test-app-db-1;dbname=lena\\', \\'root\\', \\'${DB_PASS}\\' ); echo \\'Connection successful\\'; } catch (PDOException \$e) { echo \\'Connection failed: \\' . \$e->getMessage(); exit(1); }" || exit 1
'''
        sh 'docker-compose -f docker-compose-test.yaml -p test-app down'
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
    stage('Deploy to Swarm with Canary') {
      steps {
        sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'
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
