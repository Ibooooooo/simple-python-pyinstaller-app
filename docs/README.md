# Práctica de Jenkins

## Introducción
En esta práctica realizaremos el despliegue de una aplicación Python mediante un pipeline de Jenkins, siguiendo el tutorial oficial:

[Build a Python app with PyInstaller](https://www.jenkins.io/doc/tutorials/build-a-python-app-with-pyinstaller/)

Para ello, construiremos una imagen personalizada de Jenkins basada en `jenkins/jenkins:lts` con las herramientas necesarias, así como un contenedor Docker-in-Docker (DinD). Ambos contenedores se desplegarán usando Terraform, aunque la construcción de la imagen personalizada se realizará mediante un `Dockerfile` de forma independiente.

---

## Dockerfile

Este repositorio incluye un `Dockerfile` que extiende la imagen oficial `jenkins/jenkins:lts` para incluir:

- Docker CLI
- Plugins de Jenkins: Blue Ocean, Docker Workflow y Git
- Python 3
- Pytest
- PyInstaller

Estas herramientas son necesarias para ejecutar el pipeline de la práctica.

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

### 2. Instalación de paquetes Python

```dockerfile
RUN python3 -m pip install --upgrade pip --break-system-packages && \
    pip3 install --no-cache-dir pytest pyinstaller --break-system-packages
```

* Se usa `--break-system-packages` para evitar restricciones impuestas por Debian al instalar paquetes del sistema.

### 3. Instalación de Docker CLI

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

---

## Despliegue con Terraform

Terraform se usa para desplegar dos contenedores conectados en red:

- Jenkins, usando la imagen personalizada.
- Docker-in-Docker (DinD), para permitir a Jenkins ejecutar contenedores Docker.

### Estructura básica de Terraform

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

### 1. Red personalizada

```hcl
resource "docker_network" "jenkins_net" {
  name = "jenkins_net"
}
```

### 2. Volúmenes para persistencia y certificados

```hcl
resource "docker_volume" "jenkins_home" {
  name = "jenkins_home"
}

resource "docker_volume" "docker_certs" {
  name = "docker_certs"
}
```

### 3. Imagen personalizada de Jenkins

```hcl
resource "docker_image" "jenkins_custom" {
  name = "jenkins-custom:latest"
  build {
    context    = "${path.module}/."
    dockerfile = "Dockerfile"
  }
}
```

### 4. Contenedor Jenkins

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

---

## Despliegue

Ejecuta los siguientes comandos para desplegar todo:

```bash
terraform init
terraform apply
```

Luego accede a Jenkins desde [http://localhost:8080](http://localhost:8080)

---

## Configuración inicial de Jenkins

### 1. Accede a Jenkins
Abre [http://localhost:8080](http://localhost:8080) en tu navegador.

### 2. Desbloquea Jenkins
Ejecuta el siguiente comando para obtener la contraseña inicial:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 3. Instala plugins recomendados
Selecciona “Instalar plugins recomendados” cuando Jenkins lo solicite.

### 4. Finaliza la configuración
Continúa como administrador cuando se solicite.

---

## Creación del Pipeline

1. En el panel de Jenkins, haz clic en “New Item”.
2. Introduce un nombre para el proyecto (por ejemplo, `simple-python-pyinstaller-app`).
3. Selecciona “Pipeline” como tipo de proyecto y haz clic en OK.
4. En el menú lateral, selecciona **Pipeline** y luego:

    - En “Definition” selecciona **Pipeline script from SCM**
    - En “SCM” elige **Git**
    - En “Repository URL” introduce la URL de tu repositorio
    - Haz clic en **Save**.

---

## Jenkinsfile: Pipeline Declarativo

Crea un archivo llamado `Jenkinsfile` en el directorio raíz del proyecto, con el siguiente contenido:

```groovy
pipeline {
    agent any
    options {
        skipStagesAfterUnstable()
    }
    stages {
        stage('Build') {
            steps {
                sh 'python3 -m py_compile sources/add2vals.py sources/calc.py'
                stash(name: 'compiled-results', includes: 'sources/*.py*')
            }
        }
        stage('Test') {
            steps {
                sh 'pytest --junit-xml test-reports/results.xml sources/test_calc.py'
            }
            post {
                always {
                    junit 'test-reports/results.xml'
                }
            }
        }
        stage('Deliver') {
            steps {
                sh 'pyinstaller --onefile sources/add2vals.py'
            }
            post {
                success {
                    archiveArtifacts 'dist/add2vals'
                }
            }
        }
    }
}
```

Este pipeline realiza tres etapas:

- **Build**: compila los archivos `.py` a bytecode.
- **Test**: ejecuta pruebas unitarias con `pytest`.
- **Deliver**: empaqueta la aplicación con `PyInstaller` y archiva el binario generado.

Al momento de construir el pipeline debrías de ver que todas las fases se realizan correctamente.
