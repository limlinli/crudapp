pipeline {
    agent { label 'docker-agent' }   // твой Swarm-агент (любой из 3 менеджеров)

    environment {
        APP_NAME        = 'crudapp'          // имя твоего основного стека
        CANARY_NAME     = 'crud-app-canary'   // имя канареечного стека
        DOCKER_USER     = 'popstar13'
        // BUILD_NUMBER — встроенная переменная Jenkins (1,2,3…)
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/limlinli/crudapp.git'
            }
        }

        stage('Build Images') {
            steps {
                sh '''
                    docker build -f php.Dockerfile   -t ${DOCKER_USER}/crudback:${BUILD_NUMBER} .
                    docker build -f mysql.Dockerfile -t ${DOCKER_USER}/mysql:${BUILD_NUMBER} .
                    docker tag ${DOCKER_USER}/crudback:${BUILD_NUMBER} ${DOCKER_USER}/crudback:latest
                    docker tag ${DOCKER_USER}/mysql:${BUILD_NUMBER}    ${DOCKER_USER}/mysql:latest
                '''
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials',
                                                 usernameVariable: 'USER',
                                                 passwordVariable: 'PASS')]) {
                    sh '''
                        echo $PASS | docker login -u $USER --password-stdin
                        docker push ${DOCKER_USER}/crudback:${BUILD_NUMBER}
                        docker push ${DOCKER_USER}/mysql:${BUILD_NUMBER}
                        docker push ${DOCKER_USER}/crudback:latest
                        docker push ${DOCKER_USER}/mysql:latest
                    '''
                }
            }
        }

        // ==================== CANARY ====================
        stage('Deploy Canary') {
            steps {
                sh '''
                    echo "=== Запуск Canary-версии (1 реплика) ==="
                    docker stack deploy -c docker-compose_canary.yaml ${CANARY_NAME} --with-registry-auth
                    sleep 40
                    docker service ls --filter name=${CANARY_NAME}
                '''
            }
        }

        stage('Canary Health Check') {
            steps {
                sh '''
                    echo "=== Тестируем канарейку (порт 8081) ==="
                    SUCCESS=0
                    for i in {1..12}; do
                        if curl -f --max-time 10 http://192.168.0.1:8081/index.php > /dev/null 2>&1; then
                            echo "✓ запрос $i — OK"
                            ((SUCCESS++))
                        else
                            echo "✗ запрос $i — ошибка"
                        fi
                        sleep 4
                    done

                    echo "Успешно: $SUCCESS из 12"
                    [ $SUCCESS -ge 10 ] || exit 1
                    echo "Canary прошёл проверку!"
                '''
            }
        }

        stage('Gradual Rollout') {
            steps {
                sh '''
                    echo "=== 50% трафика (2 реплики canary) ==="
                    docker service update --replicas 2 ${CANARY_NAME}_php
                    sleep 60

                    echo "=== 100% — переключаем основной стек на новую версию ==="
                    docker service update --image ${DOCKER_USER}/crudback:${BUILD_NUMBER} ${APP_NAME}_php
                    docker service update --replicas 3 ${APP_NAME}_php   # или сколько у тебя обычно
                    sleep 40

                    echo "=== Удаляем канарейку ==="
                    docker stack rm ${CANARY_NAME}
                    sleep 20
                '''
            }
        }

        stage('Final Check') {
            steps {
                sh '''
                    echo "=== Финальная проверка основной версии (порт 8080) ==="
                    for i in {1..6}; do
                        curl -f --max-time 10 http://192.168.0.1:8080/index.php || exit 1
                        echo "✓ финальный запрос $i — OK"
                        sleep 4
                    done
                    echo "Всё работает на новой версии!"
                '''
            }
        }

        stage('Show Distribution') {
            steps {
                sh '''
                    echo "=== Распределение реплик по трём менеджерам ==="
                    docker service ps ${APP_NAME}_php --no-trunc
                '''
            }
        }
    }

    post {
        success {
            echo "Canary-деплой успешно завершён!"
            sh 'docker logout || true'
        }
        failure {
            echo "Ошибка! Откатываемся..."
            sh '''
                docker stack rm ${CANARY_NAME} || true
                docker stack deploy -c docker-compose.yaml ${APP_NAME} --with-registry-auth || true
            '''
            sh 'docker logout || true'
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
