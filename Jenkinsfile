pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'app'
    CANARY_STACK_NAME = 'app-canary-stack'
    CANARY_SERVICE_NAME = 'app-canary-php'
    DOCKER_HUB_USER = 'popstar13'
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'
    BACKEND_IMAGE_NAME = 'crudback'
    DATABASE_IMAGE_NAME = 'mysql'
    MANAGER_IP = '192.168.0.1'
    NEW_IMAGE = "${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'
      }
    }

    stage('Build Docker Images') {
      steps {
        sh "docker build -f php.Dockerfile . -t ${NEW_IMAGE}"
        sh "docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/${DATABASE_IMAGE_NAME}:${BUILD_NUMBER}"
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
            docker push ${NEW_IMAGE}
            docker push ${DOCKER_HUB_USER}/${DATABASE_IMAGE_NAME}:${BUILD_NUMBER}
          '''
        }
      }
    }

    stage('Deploy Canary Stack (отдельный порт)') {
      steps {
        sh '''
          echo "=== Развёртывание Canary как отдельного стека (порт 8081) ==="
          docker stack deploy -c docker-compose_canary.yaml ${CANARY_STACK_NAME} --with-registry-auth
          sleep 40
          docker service ls --filter name=${CANARY_STACK_NAME}
        '''
      }
    }

    stage('Canary Testing (явный, порт 8081)') {
      steps {
        sh '''
          echo "=== Тестирование Canary на отдельном порту 8081 ==="
          SUCCESS=0
          TESTS=10
          for i in $(seq 1 $TESTS); do
            if curl -f -s --max-time 15 http://${MANAGER_IP}:8081/ > /dev/null; then
              SUCCESS=$((SUCCESS + 1))
              echo "✓ Тест $i пройден (явный canary)"
            else
              echo "✗ Тест $i не пройден"
            fi
            sleep 6
          done
          echo "Явный canary: $SUCCESS/$TESTS успешных"
          [ "$SUCCESS" -ge 8 ] || exit 1
        '''
      }
    }

          stage('Deploy Canary Service (тот же порт 8080)') {
      steps {
        sh '''
          echo "=== Подмешивание Canary через сетевой алиас ==="
          
          docker service create \
            --name ${CANARY_SERVICE_NAME} \
            --replicas 1 \
            --network name=app_default,alias=web-server \
            ${NEW_IMAGE}

          sleep 40
          echo "Проверка доступности Canary внутри сети:"
          docker service ls --filter name=${CANARY_SERVICE_NAME}
        '''
      }
    }


    stage('Canary Testing (смешанный трафик на 8080)') {
      steps {
        sh '''
          echo "=== Тестирование смешанного трафика (25% на canary) ==="
          SUCCESS=0
          TESTS=20
          for i in $(seq 1 $TESTS); do
            if curl -f -s --max-time 15 http://${MANAGER_IP}:8080/ > /dev/null; then
              SUCCESS=$((SUCCESS + 1))
              echo "✓ Запрос $i прошёл (часть на canary)"
            else
              echo "✗ Запрос $i не прошёл"
            fi
            sleep 3
          done
          echo "Смешанный трафик: $SUCCESS/$TESTS успешных"
          [ "$SUCCESS" -ge 18 ] || exit 1
          echo "Canary в смешанном трафике прошёл!"
        '''
      }
    }

    stage('Gradual Traffic Shift') {
      steps {
        sh '''
          echo "=== Постепенное обновление продакшена по одной реплике ==="
          docker service update \
            --image ${NEW_IMAGE} \
            --update-parallelism 1 \
            --update-delay 40s \
            --update-order start-first \
            ${APP_NAME}_web-server

          sleep 180

          echo "Удаление canary-сервиса..."
          docker service rm ${CANARY_SERVICE_NAME} || true
          echo "Удаление canary-стека..."
          docker stack rm ${CANARY_STACK_NAME} || true
        '''
      }
    }

    stage('Final Verification') {
      steps {
        sh '''
          echo "=== Финальная проверка ==="
          for i in $(seq 1 5); do
            curl -f --max-time 10 http://${MANAGER_IP}:8080/ > /dev/null && echo "✓ Тест $i пройден" || exit 1
            sleep 5
          done
          docker service ls
        '''
      }
    }
  }

  post {
    always {
      sh 'docker logout || true'
    }
    failure {
      sh "docker service rm ${CANARY_SERVICE_NAME} || true"
      sh "docker stack rm ${CANARY_STACK_NAME} || true"
    }
  }
}
