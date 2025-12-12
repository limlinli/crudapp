pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    CANARY_APP_NAME = 'app-canary'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    BACKEND_IMAGE_NAME = 'crudback'
    DATABASE_IMAGE_NAME = 'mysql'
    VERSION_TAG = "${BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'
      }
    }

    stage('Build Docker Images') {
      steps {
        sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}'
        sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/${DATABASE_IMAGE_NAME}:${BUILD_NUMBER}'
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
            docker push ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}
            docker push ${DOCKER_HUB_USER}/${DATABASE_IMAGE_NAME}:${BUILD_NUMBER}
          '''
        }
      }
    }

    stage('Deploy Canary') {
      steps {
        sh '''
          echo "=== Развертывание Canary ==="
          docker stack deploy -c docker-compose_canary.yaml ${CANARY_APP_NAME}
          sleep 80
          docker service ls --filter name=${CANARY_APP_NAME}
        '''
      }
    }

       stage('Canary Testing') {
      steps {
        sh '''
          echo "=== Тестирование Canary-версии ==="

          CANARY_SUCCESS=0
          CANARY_TESTS=10

          for i in $(seq 1 $CANARY_TESTS); do
            echo "Тест $i/$CANARY_TESTS..."

            # Попробуем главную страницу
            if curl -f -s --max-time 15 http://192.168.0.1:8081/ > /tmp/canary_response_$i.html; then
              if ! grep -iq "error\\|fatal\\|exception\\|failed\\|warning" /tmp/canary_response_$i.html; then
                CANARY_SUCCESS=$((CANARY_SUCCESS + 1))
                echo "Успешно Тест $i пройден — приложение отвечает"
              else
                echo "Ошибка Тест $i: в ответе есть слово error/fatal"
                cat /tmp/canary_response_$i.html | head -20
              fi
            else
              echo "Ошибка Тест $i: нет ответа 200"
            fi

            sleep 6
          done

          echo "Результаты: $CANARY_SUCCESS из $CANARY_TESTS успешных"

          if [ "$CANARY_SUCCESS" -lt 8 ]; then
            echo "Ошибка Canary-тестирование провалено ($CANARY_SUCCESS/10)"
            exit 1  # Это прервет пайплайн
          else
            echo "Успешно Canary-тестирование пройдено!"
          fi
        '''
      }
    }

    stage('Gradual Traffic Shift') {
      steps {
        sh '''
          echo "=== Постепенное обновление продакшена ==="

          if docker service ls --filter name=${APP_NAME}_web-server | grep -q ${APP_NAME}_web-server; then
            echo "Продакшен существует — начинаем Canary-обновление"

            # Шаг 1: Обновляем только первую реплику с большой задержкой
            echo "Шаг 1: Обновляем первую реплику (33% трафика)"
            docker service update \
              --image ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${VERSION_TAG} \
              --update-parallelism 1 \
              --update-delay 40s \
              --update-order start-first \
              ${APP_NAME}_web-server

            echo "Статус после обновления:"
            docker service ps ${APP_NAME}_web-server --no-trunc | head -20

            # Дополнительная проверка после первой реплики (опционально)
            echo "Проверка после обновления первой реплики..."
            curl -f http://${MANAGER_IP}:8080/ > /dev/null || echo "Внимание: возможны проблемы после первой реплики"

            # Шаг 2: Ускоряем обновление оставшихся реплик
            echo "Шаг 2: Ускоряем обновление оставшихся реплик"
            docker service update \
              --update-delay 10s \
              --update-parallelism 1 \
              ${APP_NAME}_web-server

            echo "Ожидание завершения полного обновления..."
            sleep 120

            echo "Обновление завершено"
            docker service ps ${APP_NAME}_web-server --no-trunc | head -20

            # Удаляем canary
            echo "Удаление canary stack..."
            docker stack rm ${CANARY_APP_NAME} || true
            sleep 20

          else
            echo "Первый деплой — разворачиваем продакшен"
            docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth
            sleep 60
          fi
        '''
      }
    }
        stage('Final Verification') {
      steps {
        sh '''
          echo "=== Финальная проверка ==="
          
          # Проверяем, что все сервисы работают
          docker service ls --filter name=${APP_NAME}
          
          # Финальное тестирование
          for i in $(seq 1 5); do
            echo "Финальный тест $i/5..."
            if curl -f --max-time 10 http://192.168.0.1:8080/ > /dev/null 2>&1; then
              echo "✓ Финальный тест $i пройден"
            else
              echo "✗ Финальный тест $i не пройден"
              exit 1
            fi
            sleep 5
          done
          
          echo "✓ Все проверки пройдены успешно"
        '''
      }
    }
  }

  post {
    success { echo "✓ Canary-деплой успешно завершен" }
    failure { 
      echo "✗ Ошибка — откат"
      sh "docker stack rm ${CANARY_APP_NAME} || true"
    }
    always { sh 'docker logout' }
  }
}
