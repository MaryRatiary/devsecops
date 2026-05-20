pipeline {
  agent any

  options {
    timestamps()
    skipDefaultCheckout(true)
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
  }

  environment {
    PYTHONUNBUFFERED = '1'
    PIP_DISABLE_PIP_VERSION_CHECK = '1'
    PIP_CACHE_DIR = '.pip-cache'
    DOCKER_BUILDKIT = '1'
    TRIVY_CACHE_DIR = '.trivycache'
  }

  stages {
    stage('Prepare variables') {
      steps {
        sh '''
          set -eu
          : "${REGISTRY:?Variable Jenkins manquante: REGISTRY}"
          : "${IMAGE_REPOSITORY:?Variable Jenkins manquante: IMAGE_REPOSITORY}"
          : "${IMAGE_TAG:?Variable Jenkins manquante: IMAGE_TAG}"
          : "${TRIVY_IMAGE:?Variable Jenkins manquante: TRIVY_IMAGE}"
          : "${KUBESCAPE_IMAGE:?Variable Jenkins manquante: KUBESCAPE_IMAGE}"
          : "${REGISTRY_CREDENTIALS_ID:?Variable Jenkins manquante: REGISTRY_CREDENTIALS_ID}"
          : "${SONARQUBE_ENV:?Variable Jenkins manquante: SONARQUBE_ENV}"
          : "${PUSH_IMAGE:?Variable Jenkins manquante: PUSH_IMAGE}"
          : "${DEPLOY_K8S:?Variable Jenkins manquante: DEPLOY_K8S}"

          if [ "$DEPLOY_K8S" = "true" ]; then
            : "${K8S_NAMESPACE:?Variable Jenkins manquante pour Kubernetes: K8S_NAMESPACE}"
            : "${K8S_DEPLOYMENT:?Variable Jenkins manquante pour Kubernetes: K8S_DEPLOYMENT}"
            : "${K8S_CONTAINER:?Variable Jenkins manquante pour Kubernetes: K8S_CONTAINER}"
          fi
        '''
        script {
          env.IMAGE_NAME = "${env.REGISTRY}/${env.IMAGE_REPOSITORY}"
          env.FINAL_IMAGE_TAG = env.IMAGE_TAG.trim()
        }
      }
    }

    stage('Checkout') {
      steps {
        checkout scm
        sh 'git rev-parse --short HEAD || true'
      }
    }

    stage('Install dependencies') {
      steps {
        sh '''
          set -eu
          REQ_HASH=$(python3.11 - <<'PY'
import hashlib, pathlib
files = ['requirements.txt']
h = hashlib.sha256()
for name in files:
    p = pathlib.Path(name)
    if p.exists():
        h.update(name.encode())
        h.update(b'::')
        h.update(p.read_bytes())
print(h.hexdigest())
PY
)

          if [ -x .venv/bin/python ] && [ -f .venv/.requirements.sha256 ] && [ "$(cat .venv/.requirements.sha256)" = "$REQ_HASH" ]; then
            echo "Dépendances déjà installées, cache .venv réutilisé."
            . .venv/bin/activate
            python --version
            exit 0
          fi

          echo "Installation/mise à jour des dépendances..."
          python3.11 -m venv .venv
          . .venv/bin/activate
          python -m pip install --upgrade pip
          pip install --index-url https://download.pytorch.org/whl/cpu torch==2.2.2
          pip install -r requirements.txt
          pip install flake8 black pytest pytest-cov pytest-html bandit safety
          echo "$REQ_HASH" > .venv/.requirements.sha256
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
          mkdir -p reports
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
          // HTML Publisher plugin absent on this Jenkins; keep pytest.html as a normal archived artifact.
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
          docker build -t ${IMAGE_NAME}:${FINAL_IMAGE_TAG} -f Dockerfile .
          mkdir -p reports
          docker image inspect ${IMAGE_NAME}:${FINAL_IMAGE_TAG} > reports/docker-image.json
        '''
      }
      post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/docker-image.json' } }
    }

    stage('Trivy scans') {
      steps {
        sh '''
          mkdir -p reports ${TRIVY_CACHE_DIR}
          docker run --rm -v "$PWD:/work" -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD/${TRIVY_CACHE_DIR}:/root/.cache/" ${TRIVY_IMAGE} fs \
            --scanners vuln \
            --skip-dirs /work/.venv --skip-dirs /work/.trivycache --skip-dirs /work/.git \
            --timeout 15m \
            --format json --output /work/reports/trivy-fs.json \
            --severity HIGH,CRITICAL --ignore-unfixed /work || true

          docker run --rm -v "$PWD:/work" -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD/${TRIVY_CACHE_DIR}:/root/.cache/" ${TRIVY_IMAGE} config \
            --skip-dirs /work/.venv --skip-dirs /work/.trivycache --skip-dirs /work/.git \
            --timeout 15m \
            --format json --output /work/reports/trivy-config.json \
            --severity HIGH,CRITICAL /work || true

          docker run --rm -v "$PWD:/work" -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD/${TRIVY_CACHE_DIR}:/root/.cache/" ${TRIVY_IMAGE} image \
            --scanners vuln \
            --timeout 15m \
            --format json --output /work/reports/trivy-image.json \
            --severity HIGH,CRITICAL --ignore-unfixed ${IMAGE_NAME}:${FINAL_IMAGE_TAG} || true
        '''
      }
      post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/trivy-*.json' } }
    }

    stage('Kubernetes/Kubescape scan') {
      steps {
        sh '''
          mkdir -p reports
          if [ -d deploy/k8s ]; then
            if command -v kubescape >/dev/null 2>&1; then
              kubescape scan framework nsa deploy/k8s \
                --format json --output reports/kubescape-nsa.json || true
            else
              echo 'Kubescape CLI absent sur Jenkins; scan ignoré pour éviter le conteneur serveur bloquant.' | tee reports/kubescape-nsa.json
            fi
          else
            echo 'Pas de manifests deploy/k8s à scanner.' | tee reports/kubescape-nsa.json
          fi
        '''
      }
      post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/kubescape-nsa.json' } }
    }

    stage('Push image') {
      when { expression { return env.PUSH_IMAGE == 'true' } }
      steps {
        withCredentials([usernamePassword(credentialsId: env.REGISTRY_CREDENTIALS_ID, usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_PASSWORD')]) {
          sh '''
            echo "$REGISTRY_PASSWORD" | docker login -u "$REGISTRY_USER" --password-stdin "$REGISTRY"
            docker push ${IMAGE_NAME}:${FINAL_IMAGE_TAG}
          '''
        }
      }
    }

    stage('Deploy Kubernetes') {
      when { expression { return env.DEPLOY_K8S == 'true' } }
      steps {
        sh '''
          kubectl -n ${K8S_NAMESPACE} set image deployment/${K8S_DEPLOYMENT} ${K8S_CONTAINER}=${IMAGE_NAME}:${FINAL_IMAGE_TAG} --record
          kubectl -n ${K8S_NAMESPACE} rollout status deployment/${K8S_DEPLOYMENT} --timeout=120s
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/**'
      echo 'Workspace conservé pour réutiliser le clone Git, .venv, pip cache, Trivy cache et Docker cache.'
    }
    success { echo "Pipeline DevSecOps OK: ${IMAGE_NAME}:${FINAL_IMAGE_TAG}" }
    unstable { echo 'Pipeline terminé avec alertes sécurité/qualité' }
    failure { echo 'Pipeline échoué' }
  }
}
