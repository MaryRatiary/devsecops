#!/bin/bash

# Configure Jenkins credentials for the pipeline
JENKINS_URL="http://localhost:8080"
JENKINS_TOKEN="your-jenkins-api-token"

# Harbor credentials
curl -X POST "$JENKINS_URL/credentials/store/system/domain/_/createCredentials" \
  -u "admin:$JENKINS_TOKEN" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "json={
    'credentials': {
      'scope': 'GLOBAL',
      'id': 'harbor-user',
      'username': 'admin',
      'password': 'harbor_password',
      '\$class': 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl'
    }
  }"

# SSH key for deployment
curl -X POST "$JENKINS_URL/credentials/store/system/domain/_/createCredentials" \
  -u "admin:$JENKINS_TOKEN" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "json={
    'credentials': {
      'scope': 'GLOBAL',
      'id': 'deploy-ssh-key',
      'privateKey': '$(cat ~/.ssh/id_rsa)',
      '\$class': 'com.cloudbees.plugins.credentials.impl.BasicSSHUserPrivateKey'
    }
  }"

echo "Credentials configured successfully!"
