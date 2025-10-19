pipeline {
<<<<<<< HEAD
  agent { label 'docker-agent' }  
  environment {
    APP_NAME = 'crudapp'  
    DOCKER_HUB_USER = ‘popstar13’  
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
        sh 'docker exec app_web curl http://localhost/cart.php'  
        sh 'docker-compose down'  
      }
    }
    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
          sh 'docker push ${DOCKER_HUB_USER}/crudback:latest'
          sh 'docker push ${DOCKER_HUB_USER}/crudmysql:latest'
=======
    agent { label 'docker' }
    environment {
        APP_VERSION = '1.0'
        DOCKERHUB_USER = 'popstar13'
    }
    stages {
        stage('Build') {
            steps {
                sh 'printenv'
                echo 'Building PHP app and Docker images'
                sh "docker build -f php.Dockerfile -t ${DOCKERHUB_USER}/crudback:${GIT_COMMIT} ."
                sh "docker build -f mysql.Dockerfile -t ${DOCKERHUB_USER}/mysql:${GIT_COMMIT} ."
            }
        }
        stage('Test') {
            steps {
                echo 'Running simple tests'
                script {
                    sh 'docker run --rm ${DOCKERHUB_USER}/crudback:${GIT_COMMIT} php -v'
                }
                sh 'sleep 10'
            }
        }
        stage('Push') {
            when { branch 'master' }
            steps {
                echo 'Pushing to Docker Hub'
                withCredentials([usernamePassword(credentialsId: 'dockerhub', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                    sh 'docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD'
                    sh "docker tag ${DOCKERHUB_USER}/crudback:${GIT_COMMIT} ${DOCKERHUB_USER}/crudback:${APP_VERSION}"
                    sh "docker tag ${DOCKERHUB_USER}/crudback:${GIT_COMMIT} ${DOCKERHUB_USER}/crudback:latest"
                    sh "docker push ${DOCKERHUB_USER}/crudback:${APP_VERSION}"
                    sh "docker push ${DOCKERHUB_USER}/crudback:latest"
                    sh "docker tag ${DOCKERHUB_USER}/mysql:${GIT_COMMIT} ${DOCKERHUB_USER}/mysql:${APP_VERSION}"
                    sh "docker tag ${DOCKERHUB_USER}/mysql:${GIT_COMMIT} ${DOCKERHUB_USER}/mysql:latest"
                    sh "docker push ${DOCKERHUB_USER}/mysql:${APP_VERSION}"
                    sh "docker push ${DOCKERHUB_USER}/mysql:latest"
                }
            }
        }
        stage('Deploy to Swarm') {
            when { branch 'master' }
            steps {
                echo 'Updating Swarm stack'
                sh 'docker stack deploy -c docker-compose.yaml crudapp --with-registry-auth'
            }
>>>>>>> b164bac37553a83fec9576f3b33b9f723b79f5f0
        }
    }
<<<<<<< HEAD
    stage('Deploy to Swarm with Canary') {
      steps {
        sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME}'  
        sh 'docker service update --replicas 1 --update-delay 10s ${APP_NAME}_web'  
        sh 'docker service update --replicas 1 --update-delay 10s ${APP_NAME}_db'
        
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
=======
    post {
        always {
            sh 'docker system prune -f'
        }
    }
>>>>>>> b164bac37553a83fec9576f3b33b9f723b79f5f0
}
