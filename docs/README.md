# Práctica de Jenkins

## Introducción
En esta práctica vamos realizar un despliegue de una aplicación Python mediante un pipeline de Jenkins
tal como se indica en el siguiente tutorial:

https://www.jenkins.io/doc/tutorials/build-a-python-app-with-pyinstaller/

Para ello vamos a necesitar construir una imagen personalizada de **Jenkins** basada en `jenkins/jenkins:lts` y también construiremos un **Docker in Docker**.
El despliegue de ambos contenedores de realizarán mediante **Terraform**.
Para crear la imagen personalizada de Jenkins usaremos un Dockerfile, esto no debe realizarse mediante Terraform.

## Dockerfile
Este repositorio contiene un `Dockerfile` para construir una imagen personalizada de **Jenkins** basada en `jenkins/jenkins:lts`, extendida con soporte para:

- Docker CLI
- Plugins de Jenkins como Blue Ocean, Docker Workflow y Git
- Python 3
- Pytest
- PyInstaller

Que son las cosas que necesitaremos para realizar la práctica.
---

### Construcción de la imagen

### 1. Instalación de herramientas base y Python
```dockerfile
RUN apt-get update && apt-get install -y \
    lsb-release \
    ca-certificates \
    curl \
    gnupg \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python
```
### 2. Instalación de paquetes Python (pytest y pyinstaller)
```dockerfile
RUN python3 -m pip install --upgrade pip --break-system-packages && \
    pip3 install --no-cache-dir pytest pyinstaller --break-system-packages
```
*--break-system-packages* se usa porque Debian ahora protege los paquetes del sistema. Esta opción nos permite instalar desde pip sin errores.

### 3. Configuración del repositorio oficial de Docker e instalación de docker-ce-cli
```dockerfile
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
> /etc/apt/sources.list.d/docker.list

RUN apt-get update && apt-get install -y docker-ce-cli
```

### 4. Instalación de plugins de Jenkins
```dockerfile
RUN jenkins-plugin-cli --plugins \
    "blueocean docker-workflow git workflow-aggregator"
```
