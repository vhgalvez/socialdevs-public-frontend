pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins/role: kaniko-builder
spec:
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command: ["/busybox/sleep"]
      args: ["infinity"]
      volumeMounts:
        - name: kaniko-secret
          mountPath: /kaniko/.docker
        - name: workspace
          mountPath: /home/jenkins/agent

    - name: nodejs
      image: node:18.20.4-alpine
      command: ["/bin/sh", "-c"]
      args: ["while true; do sleep 30; done"]
      tty: true
      volumeMounts:
        - name: workspace
          mountPath: /home/jenkins/agent

    - name: jnlp
      image: jenkins/inbound-agent:3107.v665000b_51092-10
      args: ["\${computer.jnlpmac}", "\${computer.name}"]
      volumeMounts:
        - name: workspace
          mountPath: /home/jenkins/agent

  volumes:
    - name: kaniko-secret
      secret:
        secretName: dockerhub-config
    - name: workspace
      emptyDir: {}

  restartPolicy: Never
"""
      defaultContainer 'nodejs'
    }
  }

  environment {
    IMAGE_NAME  = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG   = "${BUILD_NUMBER}"
    GITOPS_REPO = 'https://github.com/vhgalvez/socialdevs-gitops.git'
    GITOPS_PATH = 'apps/socialdevs-frontend/deployment.yaml'
    GITHUB_PAT_ID = 'github-ci-token'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Test') {
      steps {
        sh '''
          npm config set registry https://registry.npmmirror.com
          npm ci
          npm run test
        '''
      }
    }

    stage('Build & Push con Kaniko') {
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \
              --dockerfile=/home/jenkins/agent/Dockerfile \
              --context=dir:///home/jenkins/agent \
              --destination=${IMAGE_NAME}:${IMAGE_TAG} \
              --destination=${IMAGE_NAME}:latest \
              --verbosity=info
          '''
        }
      }
    }

    stage('GitOps update') {
      steps {
        withCredentials([string(credentialsId: GITHUB_PAT_ID, variable: 'GH_PAT')]) {
          sh '''
            git clone --depth 1 ${GITOPS_REPO} gitops-tmp
            cd gitops-tmp
            git config user.name "CI Bot"
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

  post {
    success { echo '✅ Pipeline finalizado con éxito' }
    failure { echo '❌ Error en el pipeline' }
  }
}