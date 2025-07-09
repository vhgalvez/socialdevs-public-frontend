pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins/role: docker-builder
spec:
  restartPolicy: Never
  volumes:
    - name: workspace-volume
      emptyDir: {}
  containers:
    - name: dind-daemon
      image: docker:25.0.3-dind
      securityContext:
        privileged: true
      env:
        - name: DOCKER_TLS_CERTDIR
          value: ""
      command: ["dockerd"]
      args:
        - "--host=tcp://0.0.0.0:2375"
        - "--host=unix:///var/run/docker.sock"
      ports:
        - containerPort: 2375
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent

    - name: docker
      image: docker:25.0.3-cli
      command: ["cat"]  # Importante para mantener contenedor activo
      env:
        - name: DOCKER_HOST
          value: tcp://localhost:2375
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent

    - name: jnlp
      image: jenkins/inbound-agent:3283.v92c105e0f819-4
      env:
        - name: JENKINS_AGENT_WORKDIR
          value: /home/jenkins/agent
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent
"""
      defaultContainer 'docker'
    }
  }

  environment {
    IMAGE_NAME  = "vhgalvez/socialdevs-public-frontend"
    IMAGE_TAG   = "${BUILD_NUMBER}"
    GITOPS_REPO = "https://github.com/vhgalvez/socialdevs-gitops.git"
    GITOPS_PATH = "apps/socialdevs-frontend/deployment.yaml"
  }

  stages {

    stage('🧾 Checkout') {
      steps {
        checkout scm
      }
    }

    stage('🐳 Build Docker Image') {
      steps {
        sh """
          echo '[INFO] Esperando a que Docker esté disponible...'
          timeout 60 bash -c 'while ! docker info >/dev/null 2>&1; do sleep 2; done'
          echo '[INFO] Docker listo.'
          docker version

          echo '[INFO] Construyendo imagen Docker...'
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
        """
      }
    }

    stage('📤 Push Docker (si hay credencial)') {
      when {
        expression { env.DOCKER_REGISTRY_CREDENTIALS_ID != null }
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: env.DOCKER_REGISTRY_CREDENTIALS_ID,
          passwordVariable: 'DOCKER_PASSWORD',
          usernameVariable: 'DOCKER_USERNAME'
        )]) {
          sh """
            echo '[INFO] Autenticando en el Docker Registry...'
            echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

            echo '[INFO] Subiendo imágenes...'
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker push ${IMAGE_NAME}:latest
          """
        }
      }
    }

    stage('🚀 GitOps: Update image tag') {
      steps {
        git branch: 'main', url: "${GITOPS_REPO}"
        sh """
          echo '[INFO] Actualizando manifiesto GitOps...'
          sed -i 's|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|' ${GITOPS_PATH} || echo '[WARN] sed no encontró línea, saltando'

          git config user.email "ci@socialdevs.dev"
          git config user.name "CI Bot"
          git commit -am "🔄 Actualiza imagen ${IMAGE_NAME} a tag ${IMAGE_TAG}" || echo '[INFO] No hay cambios que hacer'
          git push origin main || echo '[INFO] No se pudo hacer push (¿quizás sin cambios?)'
        """
      }
    }
  }

  post {
    failure {
      echo "❌ Error en el pipeline"
    }
    success {
      echo "✅ Pipeline finalizado con éxito"
    }
  }
}