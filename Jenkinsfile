pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'crudapp'
    DOCKER_HUB_USER = 'popstar13'
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
    stage('Validate Config') {
      steps {
        sh 'docker-compose config -q'  // Проверка docker-compose.yaml
      }
    }
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
    stage('Build Images') {
      steps {
        sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/crudback:latest'
        sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/mysql:latest'
      }
    }
    stage('Full Test') {
      steps {
        script {
          // 1. Запуск
          sh 'docker-compose up -d'
          echo "Waiting 40 seconds for services to start..."
          sh 'sleep 40'

          // 2. Получаем порты из запущенных контейнеров
          def webPort = sh(script: "docker port \$(docker ps -q -f name=web-server) | head -1 | cut -d: -f2", returnStdout: true).trim()
          def pmaPort = sh(script: "docker port \$(docker ps -q -f name=phpmyadmin) | head -1 | cut -d: -f2", returnStdout: true).trim()

          echo "Web server port: ${webPort}"
          echo "phpMyAdmin port: ${pmaPort}"

          // 3. Проверка: веб-сервер отвечает
          sh "curl -f http://localhost:${webPort} || exit 1"

          // 4. Проверка: phpMyAdmin отвечает
          sh "curl -f http://localhost:${pmaPort} || exit 1"

          // 5. Проверка: MySQL жив
          sh '''
            until docker exec $(docker ps -q -f name=db) mysqladmin ping -hlocalhost --silent; do
              sleep 2
            done
          '''

          // 6. Проверка: PHP подключается к БД
          sh '''
            WEB_CONTAINER=$(docker ps -q -f name=web-server)
            docker exec $WEB_CONTAINER php -r "
              \$link = @mysqli_connect('db', 'root', 'secret', 'lena');
              if (!\$link) { echo 'DB connection failed'; exit(1); }
              echo 'DB connection OK';
            " || exit 1
          '''
        }
      }
    }
    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
          sh 'docker login -u $USER -p $PASS'
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
        echo "Application deployed to Swarm: http://<any-node>:${sh(script: "docker port ${APP_NAME}_web-server 80/tcp | head -1 | cut -d: -f2", returnStdout: true).trim()}"
      }
    }
  }
  post {
    always {
      sh 'docker-compose down --volumes || true'
      sh 'docker logout || true'
    }
    success {
      echo "FULL SUCCESS: Application is 100% working and deployed to Swarm!"
    }
    failure {
      echo "TEST FAILED: Check logs above."
    }
  }
}
