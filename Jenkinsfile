pipeline {
  agent { label 'docker-agent' }  // Использует динамический агент из Swarm-cloud
  environment {
    APP_NAME = 'crudapp'  // Имя стека в Swarm
    DOCKER_HUB_USER = 'limlinli'  // Ваш логин в Docker Hub (из repo)
    GIT_REPO = 'https://github.com/limlinli/crudapp.git'  // Ваш repo
    DB_USER = 'root'  // MySQL user (из вашего dump)
    DB_PASS = 'secret'  // MySQL pass (лучше хранить в Jenkins credentials)
  }
  stages {
    stage('Checkout') {
      steps {
        git url: "${GIT_REPO}", branch: 'main'  // Клонирует код из main ветки
      }
    }
    stage('Build Docker Images') {
      steps {
        sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/crudback:latest'  // Backend (PHP+Apache)
        sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/crudmysql:latest'  // DB (MySQL)
      }
    }
    stage('Test') {
      steps {
        sh 'docker-compose up -d'  // Запускает локально для тестов
        sh 'sleep 10'  // Ждет запуска контейнеров
        sh 'docker exec app_web curl http://localhost/index.php'  // Тест: проверка главной страницы (замените на ваш URL, напр. cart.php если нужно)
        sh 'docker-compose down'  // Очищает после теста
      }
    }
    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
          sh 'docker push ${DOCKER_HUB_USER}/crudback:latest'
          sh 'docker push ${DOCKER_HUB_USER}/crudmysql:latest'
        }
      }
    }
    stage('Deploy to Swarm with Canary') {
      steps {
        sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'  // Развертывание стека
        // Canary: постепенное обновление, по 1 реплике с задержкой
        sh 'docker service update --image ${DOCKER_HUB_USER}/crudback:latest --update-delay 10s --update-parallelism 1 ${APP_NAME}_web'
        sh 'docker service update --image ${DOCKER_HUB_USER}/crudmysql:latest --update-delay 10s --update-parallelism 1 ${APP_NAME}_db'
        sh 'sleep 30'  // Ждет для мониторинга
        sh 'docker service ls'  // Проверяет статус
      }
    }
  }
  post {
    always {
      sh 'docker logout'  // Выход из Docker Hub
    }
  }
}
