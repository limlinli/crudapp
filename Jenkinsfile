pipeline {
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
        }
    }
    post {
        always {
            sh 'docker system prune -f'
        }
    }
}
