FROM jenkins/jenkins:lts

USER root

# Instalamos utilidades necesarias
RUN apt-get update && apt-get install -y \
    lsb-release \
    ca-certificates \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Agregamos clave GPG oficial de Docker
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Agregamos el repositorio oficial de Docker
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
> /etc/apt/sources.list.d/docker.list

# Instalamos Docker CLI
RUN apt-get update && apt-get install -y docker-ce-cli

USER jenkins

# Instalamos Blue Ocean y plugins relacionados con Docker
RUN jenkins-plugin-cli --plugins \
    "blueocean docker-workflow git workflow-aggregator"
