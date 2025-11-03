pipeline {
  agent { label 'docker-build' }
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

    stage('Backup current stack') {
      steps {
        sh '''
          echo "Создание резервной копии текущего стека..."
          docker service ls > /tmp/stack_before.txt || true
        '''
      }
    }

    stage('Stop Production Stack') {
      steps {
        sh '''
          echo "Остановка стека app..."
          docker stack rm ${APP_NAME} || true
          sleep 10
        '''
      }
    }

    stage('Test with docker-compose') {
      steps {
        sh '''
          echo "=== Тестовое окружение ==="
          docker-compose down -v || true
          docker-compose up -d
          sleep 60

          if ! curl -f http://192.168.0.1:8080 > /tmp/response.html; then
            echo "Ошибка HTTP"
            exit 1
          fi

          if grep -iq "Connection refused\\|Fatal error\\|SQLSTATE" /tmp/response.html; then
            echo "Ошибка подключения к БД"
            exit 1
          fi

          echo "Тест успешно пройден"
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
          sh '''
            docker login -u $DOCKER_USER -p $DOCKER_PASS
            docker push ${DOCKER_HUB_USER}/crudback:latest
            docker push ${DOCKER_HUB_USER}/mysql:latest
          '''
        }
      }
    }

    stage('Deploy to Swarm') {
      steps {
        sh '''
          echo "=== Развёртывание нового стека ==="
          docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth
          sleep 30
          docker service ls
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Деплой успешно завершён"
      sh 'docker logout'
    }
    failure {
      echo "❌ Ошибка в пайплайне — откатываемся на старый стек"
      sh '''
        if [ -f docker-compose.yaml ]; then
          echo "Перезапуск старого стека..."
          docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth || true
        else
          echo "Файл docker-compose.yaml не найден, откат невозможен"
        fi
      '''
      sh 'docker logout'
    }
  }
}
