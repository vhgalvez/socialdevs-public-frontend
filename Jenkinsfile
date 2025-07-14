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
    - name: docker-sock
      hostPath:
        path: /var/run/docker.sock
        type: Socket

  containers:
    - name: docker
      image: docker:25.0.3-cli
      tty: true
      command: ["sh", "-c", "apk add --no-cache git bash && cat"]
      volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock

    - name: nodejs
      image: node:18.20.4-alpine
      tty: true

    - name: jnlp
      image: jenkins/inbound-agent:3283.v92c105e0f819-4
      env:
        - name: JENKINS_AGENT_WORKDIR
          value: /home/jenkins/agent
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