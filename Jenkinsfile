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
          sleep 40
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
        script {
          // Проверяем, существует ли основной сервис
          if (sh(script: "docker service ls --filter name=${APP_NAME}_web-server | grep -q ${APP_NAME}_web-server", returnStatus: true) == 0) {
            echo "=== Постепенное обновление продакшена ==="

            // Шаг 1: Обновляем 1 из 3 реплик продакшена (33% трафика)
            echo "Шаг 1: Обновляем 1 реплику продакшена на v${BUILD_NUMBER}"
            sh """
              docker service update \
                --image ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${VERSION_TAG} \
                --update-parallelism 1 \
                --update-delay 30s \
                ${APP_NAME}_web-server
            """

            // Ждем стабилизации
            sleep 60

            // Мониторим метрики
            echo "Мониторинг после 33% обновления..."
            // Можно добавить реальный мониторинг, пока заглушка
            sh "docker service ps ${APP_NAME}_web-server | head -20"

            // Шаг 2: Обновляем еще 1 реплику (всего 66%)
            echo "Шаг 2: Обновляем еще 1 реплику (всего 66% трафика)"
            sh """
              docker service update \
                --image ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${VERSION_TAG} \
                ${APP_NAME}_web-server
            """

            sleep 60

            // Шаг 3: Обновляем последнюю реплику (100%)
            echo "Шаг 3: Завершаем обновление (100% трафика)"
            sh """
              docker service update \
                --image ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${VERSION_TAG} \
                ${APP_NAME}_web-server
            """

            // Проверяем, что все реплики обновлены
            sh "docker service ps ${APP_NAME}_web-server | head -20"

            // Удаляем canary stack (он больше не нужен)
            echo "Удаление canary stack..."
            sh "docker stack rm ${CANARY_APP_NAME}"
            
          } else {
            echo "=== Первый деплой приложения ==="
            sh "docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth"
            echo "Продакшен успешно развернут с нуля"
          }
        }
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
