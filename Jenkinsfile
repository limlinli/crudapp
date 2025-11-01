pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    // Добавляем тег для текущего билда
    BUILD_TAG = "build-${BUILD_NUMBER}"
    PREVIOUS_TAG = "previous-stable"
  }
  stages {
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'
      }
    }

    stage('Backup Current Stack') {
      steps {
        sh '''
          # Сохраняем информацию о текущем стеке
          echo "=== Резервное копирование текущего стека ==="
          docker stack services ${APP_NAME} --format "{{.Image}}" > current_images.txt || true
        '''
      }
    }

    stage('Build Docker Images') {
      steps {
        sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/crudback:${BUILD_TAG}'
        sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/mysql:${BUILD_TAG}'
        // Также тегируем как latest для тестов
        sh 'docker tag ${DOCKER_HUB_USER}/crudback:${BUILD_TAG} ${DOCKER_HUB_USER}/crudback:latest'
        sh 'docker tag ${DOCKER_HUB_USER}/mysql:${BUILD_TAG} ${DOCKER_HUB_USER}/mysql:latest'
      }
    }

    stage('Test with docker-compose') {
      steps {
        sh '''
          echo "=== Запуск тестового окружения ==="
          docker-compose down -v || true
          docker-compose up -d

          echo "Ожидание запуска MySQL и PHP..."
          sleep 60

          echo "Проверка веб‑сервера..."
          if ! curl -f http://192.168.0.1:8080 > /tmp/response.html; then
            echo "HTTP‑ошибка (не 2xx/3xx)"
            docker-compose logs web-server
            exit 1
          fi

          if grep -iq "Connection refused\\|Fatal error\\|SQLSTATE" /tmp/response.html; then
            echo "Ошибка в приложении: проблема с подключением к MySQL"
            docker-compose logs web-server
            docker-compose logs db
            exit 1
          fi

          echo "Тест пройден: приложение отвечает корректно"
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
          sh 'docker push ${DOCKER_HUB_USER}/crudback:${BUILD_TAG}'
          sh 'docker push ${DOCKER_HUB_USER}/mysql:${BUILD_TAG}'
          sh 'docker push ${DOCKER_HUB_USER}/crudback:latest'
          sh 'docker push ${DOCKER_HUB_USER}/mysql:latest'
        }
      }
    }

    stage('Deploy to Swarm') {
      steps {
        sh '''
          echo "=== Деплой новой версии ==="
          # Обновляем docker-compose.yaml для использования BUILD_TAG
          sed -i "s|image:.*crudback.*|image: ${DOCKER_HUB_USER}/crudback:${BUILD_TAG}|g" docker-compose.yaml
          sed -i "s|image:.*mysql.*|image: ${DOCKER_HUB_USER}/mysql:${BUILD_TAG}|g" docker-compose.yaml
          
          docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth
          sleep 30
          
          echo "=== Проверка деплоя ==="
          if ! docker service ls | grep "${APP_NAME}" | grep "1/1"; then
            echo "Сервисы не запустились корректно"
            exit 1
          fi
        '''
      }
    }
  }

  post {
    success {
      sh '''
        echo "=== Деплой успешен, помечаем как стабильную версию ==="
        docker tag ${DOCKER_HUB_USER}/crudback:${BUILD_TAG} ${DOCKER_HUB_USER}/crudback:${PREVIOUS_TAG}
        docker tag ${DOCKER_HUB_USER}/mysql:${BUILD_TAG} ${DOCKER_HUB_USER}/mysql:${PREVIOUS_TAG}
        docker push ${DOCKER_HUB_USER}/crudback:${PREVIOUS_TAG}
        docker push ${DOCKER_HUB_USER}/mysql:${PREVIOUS_TAG}
      '''
    }
    failure {
      sh '''
        echo "=== Деплой не удался, откат на предыдущую версию ==="
        # Восстанавливаем оригинальный docker-compose.yaml
        git checkout docker-compose.yaml
        
        # Пытаемся запустить предыдущую стабильную версию
        if docker pull ${DOCKER_HUB_USER}/crudback:${PREVIOUS_TAG} && docker pull ${DOCKER_HUB_USER}/mysql:${PREVIOUS_TAG}; then
          echo "Запуск предыдущей стабильной версии..."
          sed -i "s|image:.*crudback.*|image: ${DOCKER_HUB_USER}/crudback:${PREVIOUS_TAG}|g" docker-compose.yaml
          sed -i "s|image:.*mysql.*|image: ${DOCKER_HUB_USER}/mysql:${PREVIOUS_TAG}|g" docker-compose.yaml
          docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth
          echo "Откат выполнен успешно"
        else
          echo "Предыдущая стабильная версия не найдена, оставляем как есть"
        fi
      '''
    }
    always {
      sh 'docker logout'
      sh '''
        # Очистка локальных образов
        docker rmi ${DOCKER_HUB_USER}/crudback:latest ${DOCKER_HUB_USER}/mysql:latest || true
      '''
    }
  }
}
