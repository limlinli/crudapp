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

    stage('Test with docker-compose') {
      steps {
        sh '''
          echo "Запуск тестового окружения..."
          docker stack rm ${APP_NAME} || true
          docker-compose down -v || true  
          docker-compose up -d

          echo "Ожидание запуска MySQL и PHP..."
          sleep 60

          echo "Проверка веб-сервера..."
          if curl -f http://192.168.0.1:8080 > /tmp/response.html; then
            echo "УСПЕХ: Веб-сервер отвечает!"
            head -n 3 /tmp/response.html
          else
            echo "ОШИБКА: Веб-сервер не отвечает на порту 8080"
            docker-compose logs web-server
            exit 1
          fi
        '''
      }
      post {
        always {
          sh 'docker-compose down -v || true'
        }
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
        sh '''
            docker stack deploy -c docker-compose.yaml ${APP_NAME} \
            --with-registry-auth
        '''
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
