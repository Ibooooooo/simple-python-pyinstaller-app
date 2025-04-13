terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}

# Redes
resource "docker_network" "jenkins_net" {
  name = "jenkins_net"
}

# Volúmenes
resource "docker_volume" "jenkins_home" {
  name = "jenkins_home"
}

resource "docker_volume" "docker_certs" {
  name = "docker_certs"
}

# Imagen personalizada de Jenkins (Dockerfile debe estar en el mismo dir)
resource "docker_image" "jenkins_custom" {
  name         = "jenkins-custom:latest"
  build {
    context    = "${path.module}/."
    dockerfile = "Dockerfile"
  }
}

# Contenedor Jenkins
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

# Contenedor Docker-in-Docker
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
