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
      docker-compose down -v || true
      docker-compose up -d

      echo "Ожидание запуска MySQL..."
      for i in {1..30}; do
        if docker exec crud-ci-cd-db-1 mysqladmin ping -h localhost -u root -psecret --silent; then
          echo "MySQL готова!"
          break
        fi
        echo "Ожидание MySQL... ($i/30)"
        sleep 2
      done

      echo "Ожидание запуска PHP..."
      sleep 10

      echo "Проверка веб-сервера..."
      RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" http://localhost:8080)

      if [ "$RESPONSE" -ne 200 ]; then
        echo "ОШИБКА: HTTP код $RESPONSE"
        docker-compose logs web-server
        exit 1
      fi

      if grep -q "Connection refused" /tmp/response.html; then
        echo "ОШИБКА: Приложение не может подключиться к БД"
        echo "Содержимое страницы:"
        cat /tmp/response.html
        docker-compose logs web-server
        docker-compose logs db
        exit 1
      fi

      if grep -q "Fatal error" /tmp/response.html; then
        echo "ОШИБКА: Фатальная ошибка PHP"
        cat /tmp/response.html
        exit 1
      fi

      echo "УСПЕХ: Приложение работает корректно!"
      head -n 5 /tmp/response.html
    '''
  }
  post {
    always {
      sh 'docker-compose down -v || true'
    }
  }
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
        sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'
        sh 'sleep 10'
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
