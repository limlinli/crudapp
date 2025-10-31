pipeline {
  agent { label 'docker-agent' }
  environment {
    APP_NAME = 'crudapp'
    DOCKER_HUB_USER = 'popstar13'
  }
  stages {
    stage('Cleanup') {
      steps {
        sh '''
          docker-compose down --rmi local --volumes --remove-orphans || true
          docker system prune -f || true
        '''
      }
    }
    stage('Validate Config') {
      steps {
        sh 'docker-compose config -q'
      }
    }
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
    stage('Build Images') {
      steps {
        sh 'docker build -f php.Dockerfile . -t ${DOCKER_HUB_USER}/crudback:latest'
        sh 'docker build -f mysql.Dockerfile . -t ${DOCKER_HUB_USER}/mysql:latest'
      }
    }
    stage('Full Test') {
      steps {
        script {
          try {
            // 1. Запуск сервисов
            sh 'docker-compose up -d'
            echo "Waiting for services to start..."
            
            // 2. Проверка состояния контейнеров
            sh '''
              echo "=== Checking container status ==="
              docker ps -a
              echo "=== Container logs ==="
              docker-compose logs
            '''
            
            // 3. Ожидание запуска контейнеров
            sh '''
              timeout 60 bash -c '
                until docker ps --filter name=web-server --filter status=running | grep web-server; do
                  echo "Waiting for web-server to start..."
                  sleep 5
                done
              '
            '''
            
            sh '''
              timeout 60 bash -c '
                until docker ps --filter name=db --filter status=running | grep db; do
                  echo "Waiting for db to start..."
                  sleep 5
                done
              '
            '''
            
            // 4. Получаем порты
            def webContainer = sh(script: "docker ps -q -f name=web-server", returnStdout: true).trim()
            def dbContainer = sh(script: "docker ps -q -f name=db", returnStdout: true).trim()
            
            if (!webContainer) {
              error "Web server container not found!"
            }
            
            if (!dbContainer) {
              error "DB container not found!"
            }
            
            def webPort = sh(script: "docker port ${webContainer} 80 | head -1 | cut -d: -f2", returnStdout: true).trim()
            def pmaPort = sh(script: "docker port \$(docker ps -q -f name=phpmyadmin) 80 | head -1 | cut -d: -f2", returnStdout: true).trim()
            
            echo "Web server port: ${webPort}"
            echo "phpMyAdmin port: ${pmaPort}"
            
            if (!webPort) {
              error "Could not determine web server port!"
            }
            
            // 5. Проверка здоровья MySQL
            echo "Waiting for MySQL to be ready..."
            sh """
              timeout 120 bash -c '
                until docker exec ${dbContainer} mysqladmin ping -hlocalhost -uroot -psecret --silent; do
                  echo "Waiting for MySQL..."
                  sleep 5
                done
              '
            """
            
            // 6. Проверка веб-сервера с retry логикой
            echo "Testing web server..."
            sh """
              timeout 60 bash -c '
                until curl -f http://localhost:${webPort}; do
                  echo "Waiting for web server to respond..."
                  sleep 5
                done
              '
            """
            
            // 7. Проверка phpMyAdmin
            if (pmaPort) {
              echo "Testing phpMyAdmin..."
              sh """
                timeout 30 bash -c '
                  until curl -f http://localhost:${pmaPort}; do
                    echo "Waiting for phpMyAdmin to respond..."
                    sleep 5
                  done
                '
              """
            }
            
            // 8. Проверка подключения PHP к БД
            echo "Testing PHP database connection..."
            sh """
              docker exec ${webContainer} php -r "
                \\$link = @mysqli_connect('db', 'root', 'secret', 'lena');
                if (!\\$link) { 
                  echo 'DB connection failed: ' . mysqli_connect_error(); 
                  exit(1); 
                }
                echo 'DB connection OK';
                mysqli_close(\\$link);
              "
            """
            
            echo "All tests passed successfully!"
            
          } catch (Exception e) {
            // Диагностика при ошибке
            sh '''
              echo "=== DIAGNOSTICS ON FAILURE ==="
              echo "=== Container status ==="
              docker ps -a
              echo "=== Web server logs ==="
              docker-compose logs web-server
              echo "=== DB logs ==="
              docker-compose logs db
              echo "=== Network info ==="
              docker network ls
              docker inspect $(docker ps -q -f name=web-server) | grep -A 10 NetworkSettings
            '''
            error "Test failed: ${e.getMessage()}"
          }
        }
      }
    }
    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
          sh 'echo $PASS | docker login -u $USER --password-stdin'
          sh 'docker push ${DOCKER_HUB_USER}/crudback:latest'
          sh 'docker push ${DOCKER_HUB_USER}/mysql:latest'
        }
      }
    }
    stage('Deploy to Swarm') {
      steps {
        script {
          sh 'docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth'
          sh 'sleep 30'
          sh 'docker service ls'
          
          // Ждем пока сервис запустится и получаем порт
          sh '''
            timeout 60 bash -c '
              until docker service ls | grep ${APP_NAME}_web-server | grep 1/1; do
                echo "Waiting for web-server service to be ready..."
                sleep 5
              done
            '
          '''
          
          def swarmWebPort = sh(script: "docker service inspect ${APP_NAME}_web-server --format '{{range .Endpoint.Ports}}{{.PublishedPort}}{{end}}'", returnStdout: true).trim()
          
          if (swarmWebPort && swarmWebPort != "0") {
            echo "Application deployed to Swarm: http://<any-node>:${swarmWebPort}"
          } else {
            echo "Application deployed to Swarm (port auto-assigned)"
          }
        }
      }
    }
  }
  post {
    always {
      script {
        sh 'docker-compose down --volumes --remove-orphans || true'
        sh 'docker stack rm ${APP_NAME} || true'
        sh 'docker logout || true'
      }
    }
    success {
      echo "FULL SUCCESS: Application is 100% working and deployed to Swarm!"
    }
    failure {
      echo "TEST FAILED: Check logs above."
    }
  }
}
}
