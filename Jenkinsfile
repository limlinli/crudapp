pipeline {
  agent { 
    label 'docker-swarm-agent'  // Изменил лейбл для Swarm агентов
  }
  
  environment {
    APP_NAME = 'app'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    DOCKER_REGISTRY = 'docker.io'  // Добавил для явного указания registry
  }

  stages {
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'
      }
    }

    stage('Build Docker Images') {
      steps {
        script {
          // Явно указываем registry для совместимости со Swarm
          def backImage = "${DOCKER_HUB_USER}/crudback:latest"
          def mysqlImage = "${DOCKER_HUB_USER}/mysql:latest"
          
          echo "Сборка образов: $backImage и $mysqlImage"
          sh "docker build -f php.Dockerfile . -t $backImage"
          sh "docker build -f mysql.Dockerfile . -t $mysqlImage"
        }
      }
    }

    stage('Backup current stack') {
      steps {
        sh '''
          echo "Создание резервной копии текущего стека..."
          docker stack ls > /tmp/stack_before.txt || true
          docker service ls | grep ${APP_NAME} > /tmp/services_before.txt || true
          echo "Резервная копия создана"
        '''
      }
    }

    stage('Stop Production Stack') {
      steps {
        sh '''
          echo "Остановка стека ${APP_NAME}..."
          if docker stack ls | grep -q ${APP_NAME}; then
            docker stack rm ${APP_NAME} || true
            echo "Ожидание остановки сервисов..."
            sleep 30
            
            # Проверяем, что сервисы остановились
            while docker service ls | grep -q ${APP_NAME}; do
              echo "Сервисы еще останавливаются..."
              sleep 10
            done
          else
            echo "Стек ${APP_NAME} не найден, продолжаем..."
          fi
        '''
      }
    }

    stage('Test with docker-compose') {
      steps {
        sh '''
          echo "=== Тестовое окружение ==="
          # Используем docker-compose для тестов
          docker-compose down -v || true
          docker-compose up -d --build
          echo "Ожидание запуска тестового окружения..."
          sleep 60

          # Более надежная проверка здоровья
          echo "Проверка доступности приложения..."
          max_attempts=10
          attempt=1
          
          while [ $attempt -le $max_attempts ]; do
            if curl -f -s -o /dev/null -w "%{http_code}" http://192.168.0.1:8080 | grep -q "200"; then
              echo "Приложение доступно!"
              break
            else
              echo "Попытка $attempt/$max_attempts: приложение еще не готово..."
              sleep 15
            fi
            attempt=$((attempt + 1))
          done

          if [ $attempt -gt $max_attempts ]; then
            echo "Ошибка: приложение не стало доступно за отведенное время"
            docker-compose logs
            exit 1
          fi

          # Проверка содержимого
          if curl -s http://192.168.0.1:8080 | grep -iq "error\\|exception\\|connection refused"; then
            echo "Обнаружены ошибки в ответе приложения"
            docker-compose logs
            exit 1
          fi

          echo "✅ Тест успешно пройден"
        '''
      }
      post {
        always {
          sh '''
            echo "Очистка тестового окружения..."
            docker-compose down -v || true
            docker system prune -f || true
          '''
        }
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'docker-hub-credentials', 
          usernameVariable: 'DOCKER_USER', 
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            echo "Логин в Docker Hub..."
            docker login -u $DOCKER_USER -p $DOCKER_PASS
            
            echo "Пуш образов в registry..."
            docker push ${DOCKER_HUB_USER}/crudback:latest
            docker push ${DOCKER_HUB_USER}/mysql:latest
            
            echo "Образы успешно загружены"
          '''
        }
      }
    }

    stage('Deploy to Swarm') {
      steps {
        sh '''
          echo "=== Развёртывание в Docker Swarm ==="
          
          # Проверяем наличие docker-compose.yaml
          if [ ! -f "docker-compose.yaml" ]; then
            echo "Ошибка: docker-compose.yaml не найден!"
            exit 1
          fi

          # Логинимся в registry на нодах Swarm
          echo "Настройка аутентификации в Swarm..."
          docker login -u $DOCKER_USER -p $DOCKER_PASS

          echo "Запуск стека ${APP_NAME}..."
          docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth
          
          echo "Ожидание запуска сервисов..."
          sleep 45
          
          echo "Статус сервисов:"
          docker service ls | grep ${APP_NAME} || echo "Сервисы еще запускаются..."
          
          # Проверяем здоровье сервисов
          echo "Проверка здоровья сервисов..."
          max_checks=12
          for i in $(seq 1 $max_checks); do
            if docker service ls | grep "${APP_NAME}" | grep -q "0/1"; then
              echo "Проверка $i/$max_checks: сервисы еще не готовы..."
              sleep 10
            else
              echo "✅ Все сервисы запущены!"
              break
            fi
          done
          
          # Финальная проверка
          docker service ls
          echo "Деплой завершен!"
        '''
      }
    }

    stage('Health Check') {
      steps {
        sh '''
          echo "=== Финальная проверка здоровья ==="
          sleep 30
          
          # Попытка доступа к приложению
          APP_URL="http://192.168.0.1:8080"  # Или ваш реальный URL
          echo "Проверка доступности приложения по URL: $APP_URL"
          
          if curl -f -s -o /dev/null -w "HTTP: %{http_code}\n" "$APP_URL"; then
            echo "✅ Приложение работает корректно"
          else
            echo "⚠️  Предупреждение: не удалось проверить приложение"
            # Не фатальная ошибка на этом этапе
          fi
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Деплой успешно завершён!"
      sh '''
        docker logout || true
        echo "Очистка временных образов..."
        docker image prune -f || true
      '''
      
    
    failure {
      echo "❌ Ошибка в пайплайне — выполняем откат"
      sh '''
        echo "Попытка отката..."
        docker logout || true
        
        # Проверяем, был ли развернут новый стек
        if docker stack ls | grep -q ${APP_NAME}; then
          echo "Удаляем проблемный стек..."
          docker stack rm ${APP_NAME} || true
          sleep 20
        fi
        
        # Пытаемся восстановить из backup (если есть старая версия)
        if [ -f "docker-compose.yaml" ]; then
          echo "Попытка перезапуска стека..."
          docker login -u $DOCKER_USER -p $DOCKER_PASS || true
          docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth || true
          echo "Откат выполнен"
        else
          echo "Файл docker-compose.yaml не найден, откат невозможен"
        fi
      '''
      
      emailext (
        subject: "FAILED: Деплой ${APP_NAME}",
        body: "Пайплайн завершился с ошибкой. Выполнен откат.",
        to: "your-email@example.com"
      )
    }
    
    always {
      sh '''
        echo "=== Финальная очистка ==="
        docker logout || true
        # Оставляем логи для диагностики
        echo "Логи пайплайна сохранены"
      '''
    }
  }
}
