#!/bin/bash

# Script pour modifier la configuration avec sed
cd /Users/valentino/lyrx

echo "🔧 Mise à jour de la configuration..."

# 1. Mettre à jour docker-compose.yml
sed -i '' 's|ENV=production|ENV=development|g' docker-compose.yml
sed -i '' 's|restart: always|restart: unless-stopped|g' docker-compose.yml

# 2. Mettre à jour .env.example
sed -i '' 's|HARBOR_PASSWORD=change_me|HARBOR_PASSWORD=${HARBOR_PASS}|g' .env.example
sed -i '' 's|GRAFANA_PASSWORD=admin|GRAFANA_PASSWORD=${GRAFANA_PASS}|g' .env.example
sed -i '' 's|DEPLOY_SERVER=prod-server.example.com|DEPLOY_SERVER=localhost|g' .env.example

# 3. Mettre à jour prometheus.yml
sed -i '' "s|targets: \['localhost:9090'\]|targets: ['prometheus:9090']|g" monitoring/prometheus.yml
sed -i '' "s|targets: \['ml-api:8000'\]|targets: ['lyrx:8000']|g" monitoring/prometheus.yml

# 4. Mettre à jour Jenkinsfile
sed -i '' "s|REGISTRY = 'harbor.example.com'|REGISTRY = 'docker.io'|g" Jenkinsfile
sed -i '' "s|IMAGE_NAME = \"\${REGISTRY}/mlops/ml-model\"|IMAGE_NAME = \"valentino/ml-model\"|g" Jenkinsfile

# 5. Mettre à jour src/app.py
sed -i '' 's|model_path = os.getenv("MODEL_PATH", "/app/models/model.pkl")|model_path = os.getenv("MODEL_PATH", "./models/model.pkl")|g' src/app.py

# 6. Mettre à jour src/train.py
sed -i '' 's|with open("models/model.pkl", "wb")|with open("./models/model.pkl", "wb")|g' src/train.py

echo "✅ Configuration mise à jour avec succès!"
echo "📋 Fichiers modifiés:"
echo "   - docker-compose.yml"
echo "   - .env.example"
echo "   - monitoring/prometheus.yml"
echo "   - Jenkinsfile"
echo "   - src/app.py"
echo "   - src/train.py"
