pipeline {
  agent { label 'docker-agent' }

  environment {
    APP_NAME = 'app'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    DB_USER = 'root'
    DB_PASS = 'secret'
    DB_NAME = 'lena'
    DB_SERVICE = 'db'
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

    stage('Test with Production Config') {
      steps {
        script {
          echo "Деплой в Docker Swarm для тестирования..."
          
          // Инициализация Swarm если не активен
          sh '''
            if ! docker info | grep -q "Swarm: active"; then
              docker swarm init || true
            fi
          '''
          
          // Деплой стека с docker-compose.yaml (где может быть неверный пароль)
          sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'
          
          echo "Ожидание запуска сервисов..."
          sleep time: 30, unit: 'SECONDS'
          
          // Проверка что сервисы запустились
          echo "Проверка состояния сервисов..."
          sh 'docker service ls | grep ${APP_NAME}'
          
          // Получаем ID контейнера БД из Swarm
          echo "Поиск контейнера базы данных..."
          def dbContainerId = sh(
            script: "docker ps --filter name=${APP_NAME}_${DB_SERVICE} --format '{{.ID}}'",
            returnStdout: true
          ).trim()

          if (!dbContainerId) {
            error("Контейнер базы данных не найден в Swarm! Возможно, неправильный пароль в docker-compose.yaml")
          }
          
          echo "Найден контейнер БД: ${dbContainerId}"
          
          // Ждем пока БД полностью запустится
          echo "Ожидание полного запуска MySQL..."
          sleep time: 15, unit: 'SECONDS'
          
          // КРИТИЧЕСКАЯ ПРОВЕРКА: подключение к БД с паролем из environment
          // Если в docker-compose.yaml неправильный пароль - это упадет здесь
          echo "Проверка подключения к базе данных..."
          sh """
            # Пробуем подключиться к БД несколько раз (на случай долгого запуска)
            for i in {1..5}; do
              if docker exec ${dbContainerId} mysql -u${DB_USER} -p${DB_PASS} -e "USE ${DB_NAME}; SHOW TABLES;" 2>/dev/null; then
                echo "Успешное подключение к БД на попытке \$i"
                exit 0
              fi
              echo "Попытка \$i: Ожидание подключения к БД..."
              sleep 10
            done
            echo "Не удалось подключиться к базе данных после 5 попыток"
            exit 1
          """
          
          echo "Проверка доступности веб-приложения..."
          def webContainerId = sh(
            script: "docker ps --filter name=${APP_NAME}_web --format '{{.ID}}'",
            returnStdout: true
          ).trim()
          
          if (webContainerId) {
            sh """
              # Проверяем что веб-сервер отвечает
              docker exec ${webContainerId} curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -q "200" || exit 1
            """
          }
        }
      }
    }

    stage('Cleanup Test Deployment') {
      steps {
        echo "Остановка тестового деплоя..."
        sh 'docker stack rm ${APP_NAME} || true'
        sleep time: 10, unit: 'SECONDS'
        
        // Очистка возможных оставшихся контейнеров
        sh '''
          docker ps -aq --filter name=${APP_NAME} | xargs -r docker rm -f || true
        '''
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
        script {
          echo "Финальный деплой в продакшн..."
          sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'
          sh 'sleep 20'
          
          // Canary deployment для веб-сервера
          sh 'docker service update --image ${DOCKER_HUB_USER}/crudback:latest --update-delay 10s --update-parallelism 1 ${APP_NAME}_web'
          sh 'sleep 10'
          
          // Canary deployment для БД (осторожно!)
          sh 'docker service update --image ${DOCKER_HUB_USER}/mysql:latest --update-delay 20s --update-parallelism 1 ${APP_NAME}_${DB_SERVICE}'
          sh 'sleep 30'
          
          // Финальная проверка
          echo "Финальная проверка сервисов:"
          sh 'docker service ls | grep ${APP_NAME}'
          
          // Проверка что все реплики работают
          def services = sh(
            script: "docker service ls --filter name=${APP_NAME} --format '{{.Name}}/{{.Replicas}}'",
            returnStdout: true
          ).trim()
          
          if (services.contains("0/") || services.contains("_")) {
            echo "ВНИМАНИЕ: Не все сервисы развернуты корректно"
            echo "${services}"
          }
        }
      }
    }
  }

  post {
    always {
      echo "Очистка окружения..."
      sh 'docker logout || true'
      
      // Дополнительная очистка на случай падения пайплайна
      sh '''
        # Удаляем тестовые контейнеры если остались
        docker ps -aq --filter name=test_ | xargs -r docker rm -f || true
      '''
    }
    
    success {
      echo '✅ Все этапы завершены успешно! Приложение развернуто в Swarm.'
    }
    
    failure {
      echo '❌ Пайплайн завершился с ошибкой. Проверьте логи выше.'
      
      // Принудительная очистка при ошибке
      script {
        sh 'docker stack rm ${APP_NAME} || true'
        sleep time: 5, unit: 'SECONDS'
      }
    }
  }
}
