FROM jenkins/jenkins:lts

USER root

# Modo depuración
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update && apt-get install -y \
    lsb-release \
    ca-certificates \
    curl \
    gnupg \
    python3 \
    python3-pip

# Crear alias para 'python'
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Actualizar pip y luego instalar pytest
RUN python3 -m pip install --upgrade pip
RUN pip3 install --no-cache-dir pytest

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
> /etc/apt/sources.list.d/docker.list

RUN apt-get update && apt-get install -y docker-ce-cli

USER jenkins

RUN jenkins-plugin-cli --plugins \
    "blueocean docker-workflow git workflow-aggregator"
