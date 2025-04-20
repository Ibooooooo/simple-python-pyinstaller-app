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

## Despliegue con Terraform

Una vez construida la imagen personalizada de Jenkins, procedemos al despliegue de dos contenedores:

- **Jenkins**, usando nuestra imagen personalizada.
- **Docker-in-Docker (DinD)**, que permite a Jenkins ejecutar contenedores Docker desde dentro del propio contenedor.

Este despliegue se realiza con **Terraform**, utilizando el proveedor de Docker.

### Estructura de Terraform

```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}
```
### 1. Creamos una red personalizada para que Jenkins y Docker-in-Docker se comuniquen entre sí
```hcl
resource "docker_network" "jenkins_net" {
  name = "jenkins_net"
}
```
### 2. Se definen dos volúmenes
jenkins_home: persistencia de datos de Jenkins.
docker_certs: certificados TLS compartidos con Docker-in-Docker.
```hcl
resource "docker_volume" "jenkins_home" {
  name = "jenkins_home"
}
resource "docker_volume" "docker_certs" {
  name = "docker_certs"
}
```
### 3. Imagen personalizada de Jenkins
Terraform construye la imagen usando el Dockerfile:
```hcl
resource "docker_image" "jenkins_custom" {
  name = "jenkins-custom:latest"
  build {
    context    = "${path.module}/."
    dockerfile = "Dockerfile"
  }
}
```
### 4. Contenedor de Jenkins
Este contenedor utiliza la imagen personalizada y monta los volúmenes y red definidos:
```hcl
resource "docker_container" "jenkins" {
  name  = "jenkins"
  image = docker_image.jenkins_custom.name
  restart = "unless-stopped"

  ports {
    internal = 8080
    external = 8080
  }

  ports {
    internal = 50000
    external = 50000
  }

  env = [
    "DOCKER_HOST=tcp://docker:2376",
    "DOCKER_CERT_PATH=/certs/client",
    "DOCKER_TLS_VERIFY=1"
  ]

  volumes {
    volume_name    = docker_volume.jenkins_home.name
    container_path = "/var/jenkins_home"
  }

  volumes {
    volume_name    = docker_volume.docker_certs.name
    container_path = "/certs/client"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.jenkins_net.name
  }
}
```
### 5. Contenedor Docker-in-Docker (DinD)
Este contenedor permite que Jenkins ejecute comandos Docker:
```hcl
resource "docker_container" "docker" {
  name  = "docker"
  image = "docker:dind"
  restart = "unless-stopped"
  privileged = true

  env = [
    "DOCKER_TLS_CERTDIR=/certs"
  ]

  ports {
    internal = 3000
    external = 3000
  }

  ports {
    internal = 5000
    external = 5000
  }

  volumes {
    volume_name    = docker_volume.docker_certs.name
    container_path = "/certs/client"
  }

  networks_advanced {
    name = docker_network.jenkins_net.name
  }
}
```
Ejecución del despliegue
```hcl
terraform init
terraform apply
http://localhost:8080
```
