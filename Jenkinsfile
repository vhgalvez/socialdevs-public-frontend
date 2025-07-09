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
  volumes:
  - name: docker-graph
    emptyDir: {}
  - name: docker-certs
    emptyDir: {}
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
    volumeMounts:
    - name: docker-graph
      mountPath: /var/lib/docker
    - name: docker-certs
      mountPath: /certs/client
    - name: workspace-volume
      mountPath: /home/jenkins/agent

  - name: docker
    image: docker:25.0.3-cli
    command:
    - sh
    - -c
    - |
      sleep 99d
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

  restartPolicy: Never
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
    stage('🐳 Esperar Docker Daemon') {
      steps {
        sh '''
          echo "⏳ Esperando que el Docker Daemon esté listo..."
          RETRIES=0
          until docker info >/dev/null 2>&1; do
            echo "⏳ Intento $RETRIES: docker daemon aún no está listo..."
            sleep 2
            RETRIES=$((RETRIES + 1))
            if [ $RETRIES -ge 30 ]; then
              echo "❌ Timeout esperando el Docker daemon"
              exit 1
            fi
          done
          echo "✅ Docker daemon disponible"
        '''
      }
    }

    stage('🐳 Build Docker Image') {
      steps {
        sh """
          docker version
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
        """
      }
    }

    stage('📤 Push Docker (si hay credencial)') {
      when {
        expression {
          com.cloudbees.plugins.credentials.CredentialsProvider
            .lookupCredentials(
              com.cloudbees.plugins.credentials.common.StandardUsernameCredentials,
              Jenkins.instance
            ).find { it.id == 'dockerhub' } != null
        }
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker push ${IMAGE_NAME}:latest
          '''
        }
      }
    }

    stage('🚀 GitOps: Update image tag') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'git-creds',
          usernameVariable: 'GIT_USER',
          passwordVariable: 'GIT_PASS'
        )]) {
          sh '''
            git config --global user.email "ci@socialdevs.dev"
            git config --global user.name  "CI Bot"
            rm -rf gitops
            git clone https://${GIT_USER}:${GIT_PASS}@github.com/vhgalvez/socialdevs-gitops.git gitops
            cd gitops
            sed -i 's|image: vhgalvez/socialdevs-public-frontend:.*|image: vhgalvez/socialdevs-public-frontend:${IMAGE_TAG}|' ${GITOPS_PATH}
            git add ${GITOPS_PATH}
            git commit -m "🔄 Update frontend image to ${IMAGE_TAG}"
            git push origin main
          '''
        }
      }
    }
  }

  post {
    success {
      echo '✅ Pipeline completo: imagen construida y GitOps actualizado'
    }
    failure {
      echo '❌ Error en el pipeline'
    }
  }
}