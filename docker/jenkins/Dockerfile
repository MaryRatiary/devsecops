FROM jenkins/jenkins:lts-jdk17

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
      git \
      docker.io \
      python3 \
      python3-venv \
      python3-pip \
      unzip \
    && rm -rf /var/lib/apt/lists/*

USER jenkins

RUN jenkins-plugin-cli --plugins \
    git \
    workflow-aggregator \
    pipeline-stage-view \
    credentials-binding \
    timestamper \
    ansicolor \
    htmlpublisher \
    warnings-ng \
    sonar \
    ws-cleanup
