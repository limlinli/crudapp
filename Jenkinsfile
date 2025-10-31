pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
  }
  stages {
    stage('Cleanup') {
      steps {
        sh '''
          docker-compose down --rmi local --volumes --remove-orphans || true
          docker system prune -f || true
        '''
      }
    }
    stage('Validate docker-compose.yaml') {
      steps {
        sh 'docker-compose config -q'  // Проверка синтаксиса
      }
    }
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'
      }
    }
    stage('Build Images') {
      steps {
        sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/crudback:latest'
        sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/mysql:latest'
      }
    }
    stage('Test') {
      steps {
        sh 'docker-compose up -d'
        sh 'sleep 30'

        // Автоматически получить порты из docker-compose.yaml
        script {
          def compose = readYaml file: 'docker-compose.yaml'
          def webPort = compose.services.'web-server'.ports[0].split(':')[0]
          def phpmyadminPort = compose.services.phpmyadmin.ports[0].split(':')[0]

          echo "Detected web port: ${webPort}"
          echo "Detected phpMyAdmin port: ${phpmyadminPort}"

          // Проверка: веб-сервер отвечает
          sh """
            WEB_CONTAINER=\$(docker ps -q -f name=web-server)
            docker exec \$WEB_CONTAINER curl -f http://localhost || exit 1
          """

          // Проверка: порты доступны с хоста
          sh "curl -f http://localhost:${webPort} || exit 1"
          sh "curl -f http://localhost:${phpmyadminPort} || exit 1"

          // Проверка: MySQL работает
          sh """
            until docker exec \$(docker ps -q -f name=db) mysqladmin ping -h localhost --silent; do
              sleep 2
            done
          """

          // Проверка: приложение подключается к БД
          sh """
            WEB_CONTAINER=\$(docker ps -q -f name=web-server)
            docker exec \$WEB_CONTAINER php -r "
              \$link = @mysqli_connect('db', 'root', 'secret', 'lena');
              if (!\$link) { echo 'DB connection failed'; exit(1); }
              echo 'DB connection OK';
            " || exit 1
          """
        }
      }
    }
    stage('Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'docker login -u \$DOCKER_USER -p \$DOCKER_PASS'
          sh 'docker push ${DOCKER_HUB_USER}/crudback:latest'
          sh 'docker push ${DOCKER_HUB_USER}/mysql:latest'
        }
      }
    }
    stage('Deploy to Swarm') {
      steps {
        sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'
        sh 'sleep 40'
        sh 'docker service ls'
      }
    }
  }
  post {
    always {
      sh 'docker-compose down --volumes || true'
      sh 'docker logout || true'
    }
    success {
      echo 'Pipeline passed! Application works with current docker-compose.yaml'
    }
  }
}
