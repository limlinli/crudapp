pipeline {
  agent { label 'docker-agent' }  // Использует динамический агент из Swarm
  environment {
    APP_NAME = 'app'  // Имя вашего приложения
    DOCKER_HUB_USER = 'popstar13'  // Ваш логин в Docker Hub
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'  // Ваш репозиторий
  }
  stages {
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'  // Клонирует код
      }
    }
    stage('Build Docker Images') {
      steps {
        sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/crudback:latest'  // Собирает backend
        sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/mysql:latest'  // Собирает DB
      }
    }
    stage('Test') {
      steps {
        sh 'docker-compose down || true'  // Очистка
        sh 'docker-compose up -d'  // Запускает для тестов
        sh 'sleep 30'  // Ждет запуска
        sh 'docker exec app_web-server curl -s http://localhost:80 | grep -q "Список товаров"'  // Проверка страницы
        sh 'docker-compose down'
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
        sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'  // Базовое развертывание
        sh 'sleep 30'  // Ждет завершения
        // Canary: Обновляем постепенно, 1 реплика за раз
        sh 'docker service update --image ${DOCKER_HUB_USER}/crudback:latest --update-delay 10s --update-parallelism 1 ${APP_NAME}_web-server'
        sh 'docker service update --image ${DOCKER_HUB_USER}/mysql:latest --update-delay 10s --update-parallelism 1 ${APP_NAME}_db'
        sh 'sleep 30'
        sh 'docker service ls'  // Проверяем статус
      }
    }
  }
  post {
    always {
      sh 'docker logout'  // Очистка
    }
  }
}
