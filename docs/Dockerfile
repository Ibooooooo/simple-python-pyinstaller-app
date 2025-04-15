FROM jenkins/jenkins:lts

USER root

# Instalación de herramientas base y Python3
RUN apt-get update && apt-get install -y \
    lsb-release \
    ca-certificates \
    curl \
    gnupg \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Verifica que python3 y pip3 existen y funcionan
RUN which python3 && python3 --version && \
    which pip3 && pip3 --version

# Enlace simbólico para usar 'python'
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Actualiza pip e instala pytest con más logs
RUN python3 -m pip install --upgrade pip --break-system-packages && \
    pip3 install --no-cache-dir pytest pyinstaller --break-system-packages


# Instalación Docker CLI
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
> /etc/apt/sources.list.d/docker.list

RUN apt-get update && apt-get install -y docker-ce-cli

USER jenkins

# Plugins de Jenkins
RUN jenkins-plugin-cli --plugins \
    "blueocean docker-workflow git workflow-aggregator"
