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
    stage('Stop Production Stack') {
      steps {
        sh '''
          echo "Остановка стека app для теста..."
          docker stack rm ${APP_NAME} || true  # Игнорируем, если не запущен
          sleep 10  # Ждём полной остановки
        '''
      }
    }

    stage('Test with docker-compose') {
      steps {
        sh '''
          echo "=== Запуск тестового окружения ==="
          docker-compose down -v || true
          docker-compose up -d

          echo "Ожидание запуска MySQL и PHP..."
          sleep 40   # MySQL может стартовать дольше

          echo "Проверка веб‑сервера..."
          if ! curl -f http://192.168.0.1:8080 > /tmp/response.html; then
            echo "HTTP‑ошибка (не 2xx/3xx)"
            docker-compose logs web-server
            exit 1
          fi

          # Проверяем, что в ответе НЕТ строки с ошибкой БД
          if grep -iq "Connection refused\\|Fatal error\\|SQLSTATE" /tmp/response.html; then
            echo "Ошибка в приложении: проблема с подключением к MySQL"
            echo "=== Логи web‑server ==="
            docker-compose logs web-server
            echo "=== Логи db ==="
            docker-compose logs db
            exit 1
          fi

          echo "Тест пройден: приложение отвечает корректно"
          head -n 5 /tmp/response.html
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
