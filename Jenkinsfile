pipeline {

  agent { label 'docker-agent' }

  environment {

    APP_NAME = 'app'

    DOCKER_HUB_USER = 'popstar13'

    GIT_REPO = 'https://github.com/limlinli/crudapp.git'

    DB_USER = 'root'

    DB_PASS = 'secret'

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

        sh ' docker stop test_db || true'
        sh 'docker rm test_db || true'
        sh 'docker run -d -p 3307:3306 --name test_db -e MYSQL_ROOT_PASSWORD=${DB_PASS} -e MYSQL_DATABASE=${DB_NAME} ${DOCKER_HUB_USER}/mysql:latest'

        sh 'docker run -d -p 8081:80 --name test_web --link test_db:db ${DOCKER_HUB_USER}/crudback:latest'

        sh 'sleep 90'

        sh 'docker exec test_web curl -s -o /dev/null http://localhost:80'

        sh 'docker stop test_db test_web && docker rm test_db test_web'

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
    sh 'sleep 10'  // Задержка для стабилизации
    sh 'docker service update --image ${DOCKER_HUB_USER}/crudback:latest --update-delay 10s --update-parallelism 1 ${APP_NAME}_web-server'
    sh 'sleep 10'
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
