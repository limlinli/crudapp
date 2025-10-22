pipeline {
  agent { label 'docker-agent' }

  environment {
    APP_NAME = 'app'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    DB_USER = 'root'
    DB_PASS = 'secret'  // Это значение можно игнорировать, если используем docker-compose
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
        // Запуск тестового стека с docker-compose
        sh 'docker-compose -f docker-compose.yaml up -d --build'
        sh 'sleep 90'  // Ожидание запуска сервисов
        sh '''
          # Проверка доступности веб-сервера
          curl -s -o /dev/null http://localhost:8081 || exit 1
          # Получение ID контейнера базы данных
          DB_CONTAINER_ID=$(docker ps --filter name=app_db -q)
          if [ -z "$DB_CONTAINER_ID" ]; then
            echo "Контейнер базы данных не найден"
            exit 1
          fi
          # Проверка подключения к базе данных
          docker exec $DB_CONTAINER_ID mysql -u${DB_USER} -p${DB_PASS} -e "USE ${DB_NAME}; SHOW TABLES;" || exit 1
        '''
        sh 'docker-compose -f docker-compose.yaml down'  // Остановка и удаление контейнеров
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
