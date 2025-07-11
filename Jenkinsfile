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
  imagePullSecrets:
    - name: dockerhub-pull  # Asegúrate de que este Secret existe en el namespace "jenkins"
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
      command: ["sh", "-c", "apk add --no-cache git bash && cat"]
      tty: true
      env:
        - name: DOCKER_HOST
          value: tcp://localhost:2375
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent

    - name: nodejs
      image: node:18.20.4-alpine
      tty: true
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
    IMAGE_NAME  = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG   = "${BUILD_NUMBER}"
    GITOPS_REPO = 'https://github.com/vhgalvez/socialdevs-gitops.git'
    GITOPS_PATH = 'apps/socialdevs-frontend/deployment.yaml'
    DOCKER_CRED_ID = 'dockerhub-credentials'
    GITHUB_PAT_ID  = 'github-ci-token'
  }

  stages {
    stage('🧾 Checkout código') {
      steps {
        checkout scm
      }
    }

    stage('🧪 Test') {
      steps {
        container('nodejs') {
          sh '''
            echo "[TEST] Instalando dependencias y ejecutando pruebas..."
            npm config set registry https://registry.npmmirror.com
            npm ci
            npm run test
          '''
        }
      }
    }

    stage('🐳 Build & Tag') {
      steps {
        container('docker') {
          sh '''
            echo "[DOCKER] Esperando daemon..."
            timeout 60 sh -c 'until docker info >/dev/null 2>&1; do sleep 2; done'

            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
          '''
        }
      }
    }

    stage('📤 Push a Docker Hub') {
      steps {
        container('docker') {
          withCredentials([usernamePassword(
            credentialsId: DOCKER_CRED_ID,
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
    }

    stage('🚀 GitOps update') {
      steps {
        container('docker') {
          withCredentials([string(credentialsId: GITHUB_PAT_ID, variable: 'GH_PAT')]) {
            sh '''
              set -e

              git clone ${GITOPS_REPO} gitops-tmp
              cd gitops-tmp

              git config user.name  "CI Bot"
              git config user.email "ci@socialdevs.dev"

              git remote set-url origin https://x-access-token:${GH_PAT}@github.com/vhgalvez/socialdevs-gitops.git

              sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" "${GITOPS_PATH}"
              git add "${GITOPS_PATH}"

              if git diff --cached --quiet; then
                echo "[INFO] Manifiesto ya actualizado."
              else
                git commit -m "🔄 Actualiza a ${IMAGE_NAME}:${IMAGE_TAG}"
                git push origin main
              fi
            '''
          }
        }
      }
    }
  }

  post {
    success {
      echo '✅ Pipeline finalizado con éxito'
    }
    failure {
      echo '❌ Error en el pipeline'
    }
  }
}