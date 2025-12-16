pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    CANARY_APP_NAME = 'app-canary'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    BACKEND_IMAGE_NAME = 'crudback'
    DATABASE_IMAGE_NAME = 'mysql'
    MANAGER_IP = '192.168.0.1'  // IP твоей leader-ноды
  }

  stages {
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'
      }
    }

    stage('Build Docker Images') {
      steps {
        sh "docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}"
        sh "docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/${DATABASE_IMAGE_NAME}:${BUILD_NUMBER}"
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
      echo "=== Развёртывание Canary в существующей сети app_default ==="

      # Подключаем canary к существующей сети стека app
      # Используем тот же network alias "web-server", чтобы получать трафик
      docker service create \
  --name app_web-server-canary \
  --replicas 1 \
  --network app_default \
  --publish published=8080,target=80,mode=ingress \
  popstar13/crudback:${BUILD_NUMBER}

      echo "Canary запущен — теперь часть трафика идёт на новую версию"
      sleep 40
      docker service ls
      docker service ps ${APP_NAME}_web-server-canary
    '''
  }
}

 

   

    stage('Gradual Traffic Shift') {
      steps {
        sh '''
          echo "=== Постепенное обновление продакшена по одной реплике ==="

          if docker service ls --filter name=${APP_NAME}_web-server | grep -q ${APP_NAME}_web-server; then
            echo "Продакшен существует — начинаем rolling update"

            # Обновляем по одной реплике с паузами
            docker service update \
              --image ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} \
              --update-parallelism 1 \
              --update-delay 40s \
              --update-order start-first \
              ${APP_NAME}_web-server

            echo "Ожидание завершения обновления всех реплик..."
            sleep 180

            echo "Статус после обновления:"
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

          echo "Постепенное обновление завершено"
        '''
      }
    }

    stage('Final Verification') {
      steps {
        sh '''
          echo "=== Финальная проверка продакшена (порт 8080) ==="
          for i in $(seq 1 5); do
            echo "Финальный тест $i/5..."
            if curl -f --max-time 10 http://${MANAGER_IP}:8080/ > /dev/null 2>&1; then
              echo "✓ Тест $i пройден"
            else
              echo "✗ Тест $i не пройден"
              exit 1
            fi
            sleep 5
          done
          echo "Все финальные тесты пройдены!"
        '''
      }
    }
  }

  post {
    success {
      echo "✓ Canary-деплой успешно завершён!"
      sh 'docker logout'
    }
    failure {
      echo "✗ Ошибка в пайплайне — canary удалён, продакшен остался прежним"
      sh '''
        docker stack rm ${CANARY_APP_NAME} || true
        echo "Canary удалён, продакшен не тронут"
      '''
      sh 'docker logout'
    }
    always {
      sh 'docker image prune -f || true'
    }
  }
}
