# Guide DevSecOps Lyrx

Ce projet contient maintenant une base plus fonctionnelle pour Jenkins, Trivy, SonarQube et Kubernetes/Kubescape.

## Services locaux

Application seule :

```bash
docker compose up -d lyrx
```

Stack CI locale Jenkins + SonarQube :

```bash
docker compose up -d
```

Cela démarre automatiquement : app + Jenkins + SonarQube + Postgres SonarQube.

URLs :
- App : http://localhost:8000
- Jenkins : http://localhost:8081
- SonarQube : http://localhost:9000

## Jenkins

Le service Jenkins lancé par `docker compose up -d` utilise `docker/jenkins/Dockerfile`.
Il installe Docker CLI, Git, Python/venv et les plugins Jenkins utiles au pipeline.

Configuration du job Jenkins :
- Definition : `Pipeline script from SCM`
- SCM : `Git`
- Repository URL : `https://github.com/MaryRatiary/devsecops.git`
- Credentials : `- aucun -` si le repo est public
- Branch Specifier : `*/deploy`
- Script Path : `Jenkinsfile`
- Lightweight checkout : activé

Attention : le dépôt réel a seulement la branche `deploy`. Si Jenkins reste sur `*/master`, il ne trouvera pas le Jenkinsfile.

Le fichier `Jenkinsfile` exécute :
1. Installation Python
2. Lint Black/Flake8
3. Tests + couverture
4. SAST Bandit/Safety
5. Analyse SonarQube
6. Build Docker
7. Scans Trivy filesystem/config/image
8. Scan Kubernetes avec Kubescape
9. Push image optionnel
10. Déploiement Kubernetes optionnel

Credentials Jenkins recommandés :
- `registry-credentials` : username/password Harbor ou Docker Registry
- Installation SonarQube nommée `SonarQube`
- Outils Jenkins : Docker, Python3, sonar-scanner, kubectl si déploiement activé

Paramètres utiles :
- `REGISTRY` : registry cible, ex. `harbor.example.com`
- `IMAGE_REPOSITORY` : repository image, ex. `mlops/lyrx`
- `PUSH_IMAGE` : pousser l'image après build
- `DEPLOY_K8S` : déployer sur Kubernetes

## Trivy manuel

```bash
mkdir -p reports
docker run --rm -v "$PWD:/work" aquasec/trivy:latest fs --severity HIGH,CRITICAL --format json --output /work/reports/trivy-fs.json /work
docker run --rm -v "$PWD:/work" aquasec/trivy:latest config --severity HIGH,CRITICAL --format json --output /work/reports/trivy-config.json /work
docker build -t lyrx:local .
docker run --rm -v "$PWD:/work" -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity HIGH,CRITICAL --format json --output /work/reports/trivy-image.json lyrx:local
```

## Kubernetes / Kubescape

Manifests : `deploy/k8s/lyrx.yaml`

Scan sécurité :

```bash
docker run --rm -v "$PWD:/work" quay.io/kubescape/kubescape:latest scan framework nsa /work/deploy/k8s --format json --output /work/reports/kubescape-nsa.json
```

Déploiement :

```bash
kubectl apply -f deploy/k8s/lyrx.yaml
kubectl -n lyrx rollout status deployment/lyrx
```

## SonarQube

Fichier de configuration : `sonar-project.properties`

Commande locale si `sonar-scanner` est installé :

```bash
sonar-scanner -Dsonar.host.url=http://localhost:9000 -Dsonar.token=<TOKEN>
```
