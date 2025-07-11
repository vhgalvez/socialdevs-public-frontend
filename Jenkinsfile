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
    - name: dockerhub-pull
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
    DOCKER_REGISTRY_CREDENTIALS_ID = 'dockerhub-credentials'
    GITHUB_CREDENTIALS_ID          = 'github-ci-token'
  }

  stages {
    stage('🧾 Checkout código') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: '*/main']],
          userRemoteConfigs: [[url: 'https://github.com/vhgalvez/socialdevs-public-frontend.git']]
        ])
      }
    }

    stage('🧪 Ejecutar tests') {
      steps {
        container('nodejs') {
          sh '''
            echo "[TEST] Instalando dependencias y ejecutando pruebas unitarias..."
            npm config set registry https://registry.npmmirror.com
            npm ci
            npm run test
          '''
        }
      }
    }

    stage('🐳 Build Docker') {
      steps {
        sh '''
          echo "[INFO] Esperando Docker daemon…"
          timeout 60 sh -c 'until docker info >/dev/null 2>&1; do sleep 2; done'
          echo "[INFO] Docker listo."

          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          docker tag  ${IMAGE_NAME}:${IMAGE_TAG}  ${IMAGE_NAME}:latest
        '''
      }
    }

    stage('📤 Push a Docker Hub') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: DOCKER_REGISTRY_CREDENTIALS_ID,
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

    stage('🚀 GitOps: actualiza manifiesto') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: GITHUB_CREDENTIALS_ID,
          usernameVariable: 'GH_USER',
          passwordVariable: 'GH_TOKEN'
        )]) {
          sh '''
            set -e
            git clone https://${GH_USER}:${GH_TOKEN}@github.com/vhgalvez/socialdevs-gitops.git gitops-tmp
            cd gitops-tmp

            git config user.name  "CI Bot"
            git config user.email "ci@socialdevs.dev"

            sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" ${GITOPS_PATH}
            git add ${GITOPS_PATH}
            if ! git diff --cached --quiet; then
              git commit -m "🔄 Actualiza a ${IMAGE_NAME}:${IMAGE_TAG}"
              git push origin main
            else
              echo "[INFO] Manifiesto ya actualizado, no hay cambios que subir."
            fi
          '''
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