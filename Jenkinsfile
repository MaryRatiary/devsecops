pipeline {
    agent any

    environment {
        DOCKER_DRIVER = 'overlay2'
        REGISTRY = 'harbor.example.com'
        REGISTRY_USER = credentials('harbor-user')
        REGISTRY_PASSWORD = credentials('harbor-password')
        IMAGE_NAME = "${REGISTRY}/mlops/ml-model"
        IMAGE_TAG = "${BUILD_NUMBER}"
        SSH_KEY = credentials('deploy-ssh-key')
    }

    stages {
        stage('Lint') {
            steps {
                script {
                    sh '''
                        python -m pip install flake8 black
                        flake8 src/ --count --select=E9,F63,F7,F82 --show-source --statistics
                        black --check src/
                    '''
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    sh '''
                        pip install -r requirements.txt
                        pip install pytest pytest-cov
                        pytest tests/ -v --cov=src --cov-report=term --cov-report=xml
                    '''
                }
            }
            post {
                always {
                    junit 'test-results.xml'
                    publishCoverage adapters: [coberturaAdapter('coverage.xml')]
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    sh '''
                        echo ${REGISTRY_PASSWORD} | docker login -u ${REGISTRY_USER} --password-stdin ${REGISTRY}
                        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f docker/Dockerfile .
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                    '''
                }
            }
        }

        stage('Scan') {
            steps {
                script {
                    sh '''
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG}
                    '''
                }
            }
            post {
                always {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh 'echo "Security scan completed"'
                    }
                }
            }
        }

        stage('Push to Harbor') {
            when {
                branch 'main'
            }
            steps {
                script {
                    sh '''
                        echo ${REGISTRY_PASSWORD} | docker login -u ${REGISTRY_USER} --password-stdin ${REGISTRY}
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                    '''
                }
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                script {
                    sh '''
                        mkdir -p ~/.ssh
                        cat ${SSH_KEY} > ~/.ssh/deploy_key
                        chmod 600 ~/.ssh/deploy_key
                        ssh-keyscan -H ${DEPLOY_SERVER} >> ~/.ssh/known_hosts 2>/dev/null || true
                        
                        scp -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no \
                            docker-compose.yml ${DEPLOY_USER}@${DEPLOY_SERVER}:/opt/ml-app/
                        
                        scp -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no \
                            .env.production ${DEPLOY_USER}@${DEPLOY_SERVER}:/opt/ml-app/.env
                        
                        ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no \
                            ${DEPLOY_USER}@${DEPLOY_SERVER} \
                            "cd /opt/ml-app && docker-compose pull && docker-compose up -d"
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
