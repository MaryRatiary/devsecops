# Guide DevSecOps Lyrx

Ce projet utilise des variables dans `.env` / `.env.example` pour éviter les valeurs figées.
Aucun push ne doit utiliser `:latest` : toujours une version explicite.

## Préparation

```bash
cp .env.example .env
```

Modifie `.env` selon ta machine, par exemple :

```bash
REGISTRY=localhost:8082
IMAGE_REPOSITORY=mlops/lyrx
APP_VERSION=1.0.0
APP_IMAGE=localhost:8082/mlops/lyrx:1.0.0
```

## Services locaux

Application seule :

```bash
docker compose --env-file .env up -d lyrx
```

Stack CI locale Jenkins + SonarQube :

```bash
docker compose --env-file .env up -d
```

URLs selon `.env` :
- App : `http://localhost:${APP_PORT}`
- Jenkins : `http://localhost:${JENKINS_HTTP_PORT}`
- SonarQube : `http://localhost:${SONARQUBE_PORT}`

## Harbor manuel

```bash
source .env
docker login ${REGISTRY}
docker build -t ${REGISTRY}/${IMAGE_REPOSITORY}:${APP_VERSION} .
docker push ${REGISTRY}/${IMAGE_REPOSITORY}:${APP_VERSION}
```

## Jenkins

Configuration du job Jenkins :
- Definition : `Pipeline script from SCM`
- SCM : `Git`
- Repository URL : `https://github.com/MaryRatiary/devsecops.git`
- Credentials : `- aucun -` si le repo est public
- Branch Specifier : `*/deploy`
- Script Path : `Jenkinsfile`
- Lightweight checkout : activé

Paramètres Jenkins importants :
- `REGISTRY` : ex. `host.docker.internal:8082` si Jenkins tourne dans Docker et Harbor sur le Mac
- `IMAGE_REPOSITORY` : ex. `mlops/lyrx`
- `IMAGE_TAG` : version explicite, ex. `1.0.0`. Vide = numéro du build Jenkins
- `TRIVY_IMAGE` : ex. `aquasec/trivy:0.58.1`
- `KUBESCAPE_IMAGE` : ex. `quay.io/kubescape/kubescape:v3.0.17`
- `REGISTRY_CREDENTIALS_ID` : ex. `registry-credentials`
- `PUSH_IMAGE` : `true` pour push vers Harbor
- `DEPLOY_K8S` : `false` si tu veux seulement push l'image

Credential Jenkins Harbor :
- Type : Username with password
- ID : valeur de `REGISTRY_CREDENTIALS_ID`
- Username : user Harbor
- Password : password Harbor

## Trivy manuel

```bash
source .env
mkdir -p reports
docker run --rm -v "$PWD:/work" ${TRIVY_IMAGE} fs --severity HIGH,CRITICAL --format json --output /work/reports/trivy-fs.json /work
docker run --rm -v "$PWD:/work" ${TRIVY_IMAGE} config --severity HIGH,CRITICAL --format json --output /work/reports/trivy-config.json /work
docker run --rm -v "$PWD:/work" -v /var/run/docker.sock:/var/run/docker.sock ${TRIVY_IMAGE} image --severity HIGH,CRITICAL --format json --output /work/reports/trivy-image.json ${REGISTRY}/${IMAGE_REPOSITORY}:${APP_VERSION}
```

## Kubernetes / Kubescape

Template variables : `deploy/k8s/lyrx.yaml.tpl`
Manifest généré exemple : `deploy/k8s/lyrx.yaml`

Générer un manifest depuis les variables :

```bash
source .env
IMAGE_TAG=${APP_VERSION} envsubst < deploy/k8s/lyrx.yaml.tpl > deploy/k8s/lyrx.yaml
```

Scan sécurité :

```bash
source .env
docker run --rm -v "$PWD:/work" ${KUBESCAPE_IMAGE} scan framework nsa /work/deploy/k8s --format json --output /work/reports/kubescape-nsa.json
```

Déploiement :

```bash
kubectl apply -f deploy/k8s/lyrx.yaml
kubectl -n ${K8S_NAMESPACE} rollout status deployment/${K8S_DEPLOYMENT}
```

## SonarQube

Fichier de configuration : `sonar-project.properties`

Commande locale si `sonar-scanner` est installé :

```bash
sonar-scanner -Dsonar.host.url=http://localhost:${SONARQUBE_PORT} -Dsonar.token=<TOKEN>
```
