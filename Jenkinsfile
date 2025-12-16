pipeline {
  agent { label 'docker-agent' }  // Динамический агент на любой ноде
  environment {
    APP_NAME = 'app'
    CANARY_SERVICE_NAME = 'app_canary_php'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    BACKEND_IMAGE_NAME = 'crudback'
    DATABASE_IMAGE_NAME = 'mysql'
    MANAGER_IP = '192.168.0.1'  // IP твоей leader-ноды
    PROD_NETWORK = 'app_app_network'  // Имя сети из prod-стека (app_ + имя сети в compose)
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
          echo "=== Создание Canary-сервиса (получает ~25% трафика на 8080) ==="

          docker service create \
            --name ${CANARY_SERVICE_NAME} \
            --replicas 1 \
            --network ${PROD_NETWORK} \
            --network-alias web-server \
            --publish mode=ingress,target=80,published=8080 \
            --env CANARY_VERSION=true \
            --env APP_ENV=canary \
            --detach=false \
            ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}

          echo "Canary запущен"
          sleep 40
          docker service ls
          docker service ps ${CANARY_SERVICE_NAME}
        '''
      }
    }

    stage('Canary Testing') {
  steps {
    sh '''
      echo "=== Тестирование Canary (проверка по логам сервиса) ==="
      # Сохраняем состояние логов перед тестом
      docker service logs ${CANARY_SERVICE_NAME} --raw 2>/dev/null | wc -l > /tmp/before.txt || echo 0 > /tmp/before.txt

      echo "Отправляем 20 запросов на 8080..."
      for i in $(seq 1 20); do
        curl -s --max-time 15 http://${MANAGER_IP}:8080/ > /dev/null
        sleep 3
      done

      # Считаем новые строки в логах
      docker service logs ${CANARY_SERVICE_NAME} --raw 2>/dev/null | wc -l > /tmp/after.txt || echo 0 > /tmp/after.txt
      BEFORE=$(cat /tmp/before.txt)
      AFTER=$(cat /tmp/after.txt)
      HITS=$((AFTER - BEFORE))

      echo "Запросов дошло на canary: $HITS"
      if [ "$HITS" -ge 3 ]; then
        echo "Canary успешно получает трафик!"
      else
        echo "Canary НЕ получает трафик!"
        exit 1
      fi
    '''
  }
}

    stage('Gradual Traffic Shift') {
      steps {
        sh '''
          echo "=== Постепенное обновление продакшена по одной реплике ==="

          docker service update \
            --image ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} \
            --update-parallelism 1 \
            --update-delay 40s \
            --update-order start-first \
            ${APP_NAME}_web-server

          echo "Ожидание завершения rolling update..."
          sleep 180

          echo "Статус после обновления:"
          docker service ps ${APP_NAME}_web-server | head -20

          echo "Удаление canary..."
          docker service rm ${CANARY_SERVICE_NAME} || true
          sleep 20
        '''
      }
    }

    stage('Final Verification') {
      steps {
        sh '''
          echo "=== Финальная проверка продакшена ==="
          for i in $(seq 1 5); do
            echo "Финальный тест $i/5..."
            curl -f --max-time 10 http://${MANAGER_IP}:8080/ > /dev/null && echo "✓ Тест $i пройден" || exit 1
            sleep 5
          done
          echo "Все финальные тесты пройдены!"
        '''
      }
    }
  }

  post {
    always {
      sh 'docker logout || true'
      sh 'docker image prune -f || true'
    }
    failure {
      echo "Ошибка — удаляем canary"
      sh "docker service rm ${CANARY_SERVICE_NAME} || true"
    }
  }
}
