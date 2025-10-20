pipeline {
       agent { label 'docker-agent' }
       environment {
         APP_NAME = 'crudapp'
         DOCKER_HUB_USER = 'limlinli'
         GIT_REPO = 'https://github.com/limlinli/crudapp.git'
         DB_USER = 'root'
         DB_PASS = 'secret'
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
             sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/crudmysql:latest'
           }
         }
         stage('Test') {
           steps {
             sh 'docker-compose up -d'
             sh 'sleep 10'
             sh 'docker exec app_web curl http://localhost/index.php'
             sh 'docker-compose down'
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
             sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'
             sh 'docker service update --image ${DOCKER_HUB_USER}/crudback:latest --update-delay 10s --update-parallelism 1 ${APP_NAME}_web'
             sh 'docker service update --image ${DOCKER_HUB_USER}/crudmysql:latest --update-delay 10s --update-parallelism 1 ${APP_NAME}_db'
             sh 'sleep 30'
             sh 'docker service ls'
           }
         }
       }
       post {
         always {
           sh 'docker logout'
         }
       }
     }
