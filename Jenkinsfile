pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'REGISTRY', defaultValue: 'harbor.example.com', description: 'Registry Docker/Harbor')
    string(name: 'IMAGE_REPOSITORY', defaultValue: 'mlops/lyrx', description: 'Nom repository image')
    booleanParam(name: 'PUSH_IMAGE', defaultValue: false, description: 'Push image seulement si credentials configurés')
    booleanParam(name: 'DEPLOY_K8S', defaultValue: false, description: 'Déployer sur Kubernetes')
  }

  environment {
    PYTHONUNBUFFERED = '1'
    PIP_DISABLE_PIP_VERSION_CHECK = '1'
    IMAGE_NAME = "${params.REGISTRY}/${params.IMAGE_REPOSITORY}"
    IMAGE_TAG = "${BUILD_NUMBER}"
    TRIVY_CACHE_DIR = '.trivycache'
    SONARQUBE_ENV = 'SonarQube'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'git rev-parse --short HEAD || true'
      }
    }

    stage('Install dependencies') {
      steps {
        sh '''
          python3 -m venv .venv
          . .venv/bin/activate
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install flake8 black pytest pytest-cov pytest-html bandit safety
        '''
      }
    }

    stage('Quality - lint') {
      steps {
        sh '''
          . .venv/bin/activate
          black --check main.py src tests || true
          flake8 main.py src tests --count --select=E9,F63,F7,F82 --show-source --statistics
        '''
      }
    }

    stage('Unit tests + coverage') {
      steps {
        sh '''
          . .venv/bin/activate
          pytest tests -v \
            --junitxml=reports/junit.xml \
            --cov=src --cov=main \
            --cov-report=term \
            --cov-report=xml:reports/coverage.xml \
            --html=reports/pytest.html --self-contained-html
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'reports/junit.xml'
          publishHTML(target: [reportDir: 'reports', reportFiles: 'pytest.html', reportName: 'Pytest Report', allowMissing: true, keepAll: true, alwaysLinkToLastBuild: true])
          archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/**'
        }
      }
    }

    stage('SAST - Bandit / Safety') {
      steps {
        sh '''
          . .venv/bin/activate
          mkdir -p reports
          bandit -r main.py src -f json -o reports/bandit.json || true
          safety check --full-report --json > reports/safety.json || true
        '''
      }
      post {
        always { archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/bandit.json,reports/safety.json' }
      }
    }

    stage('SonarQube analysis') {
      when { expression { return env.SONAR_HOST_URL || true } }
      steps {
        script {
          catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
            withSonarQubeEnv(env.SONARQUBE_ENV) {
              sh '''
                sonar-scanner \
                  -Dsonar.projectKey=lyrx \
                  -Dsonar.projectName=lyrx \
                  -Dsonar.sources=main.py,src \
                  -Dsonar.tests=tests \
                  -Dsonar.python.coverage.reportPaths=reports/coverage.xml
              '''
            }
          }
        }
      }
    }

    stage('Docker build') {
      steps {
        sh '''
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile .
          mkdir -p reports
          docker image inspect ${IMAGE_NAME}:${IMAGE_TAG} > reports/docker-image.json
        '''
      }
      post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/docker-image.json' } }
    }

    stage('Trivy scans') {
      steps {
        sh '''
          mkdir -p reports ${TRIVY_CACHE_DIR}
          docker run --rm -v "$PWD:/work" -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD/${TRIVY_CACHE_DIR}:/root/.cache/" aquasec/trivy:0.58.1 fs \
            --format json --output /work/reports/trivy-fs.json \
            --severity HIGH,CRITICAL --ignore-unfixed /work || true

          docker run --rm -v "$PWD:/work" -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD/${TRIVY_CACHE_DIR}:/root/.cache/" aquasec/trivy:0.58.1 config \
            --format json --output /work/reports/trivy-config.json \
            --severity HIGH,CRITICAL /work || true

          docker run --rm -v "$PWD:/work" -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD/${TRIVY_CACHE_DIR}:/root/.cache/" aquasec/trivy:0.58.1 image \
            --format json --output /work/reports/trivy-image.json \
            --severity HIGH,CRITICAL --ignore-unfixed ${IMAGE_NAME}:${IMAGE_TAG} || true
        '''
      }
      post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/trivy-*.json' } }
    }

    stage('Kubernetes/Kubescape scan') {
      steps {
        sh '''
          mkdir -p reports
          if [ -d deploy/k8s ]; then
            docker run --rm -v "$PWD:/work" quay.io/kubescape/kubescape:v3.0.17 scan framework nsa /work/deploy/k8s \
              --format json --output /work/reports/kubescape-nsa.json || true
          else
            echo 'Pas de manifests deploy/k8s à scanner.' | tee reports/kubescape-nsa.json
          fi
        '''
      }
      post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/kubescape-nsa.json' } }
    }

    stage('Push image') {
      when {
        allOf {
          branch 'main'
          expression { return params.PUSH_IMAGE }
        }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'registry-credentials', usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_PASSWORD')]) {
          sh '''
            echo "$REGISTRY_PASSWORD" | docker login -u "$REGISTRY_USER" --password-stdin "$REGISTRY"
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
          '''
        }
      }
    }

    stage('Deploy Kubernetes') {
      when {
        allOf {
          branch 'main'
          expression { return params.DEPLOY_K8S }
        }
      }
      steps {
        sh '''
          kubectl -n lyrx set image deployment/lyrx lyrx=${IMAGE_NAME}:${IMAGE_TAG} --record
          kubectl -n lyrx rollout status deployment/lyrx --timeout=120s
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/**'
      cleanWs(deleteDirs: true, disableDeferredWipeout: true)
    }
    success { echo 'Pipeline DevSecOps OK' }
    unstable { echo 'Pipeline terminé avec alertes sécurité/qualité' }
    failure { echo 'Pipeline échoué' }
  }
}
