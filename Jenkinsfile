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
      image: gcr.io/kaniko-project/executor:latest
      command:
        - cat
      tty: true
      volumeMounts:
        - name: kaniko-secret
          mountPath: /kaniko/.docker
        - name: workspace
          mountPath: /workspace

    - name: nodejs
      image: node:18.20.4-alpine
      command: ["cat"]
      tty: true
      volumeMounts:
        - name: workspace
          mountPath: /workspace

    - name: jnlp
      image: jenkins/inbound-agent:latest
      volumeMounts:
        - name: workspace
          mountPath: /workspace

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
    IMAGE_NAME     = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG      = "${BUILD_NUMBER}"
    GITOPS_REPO    = 'https://github.com/vhgalvez/socialdevs-gitops.git'
    GITOPS_PATH    = 'apps/socialdevs-frontend/deployment.yaml'
    GITHUB_PAT_ID  = 'github-ci-token'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
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

    stage('Debug Dockerfile') {
      steps {
        sh 'find /workspace -name Dockerfile || true'
      }
    }

    stage('Build & Push con Kaniko') {
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \
              --dockerfile=Dockerfile \
              --context=dir:///workspace \
              --destination=${IMAGE_NAME}:${IMAGE_TAG} \
              --destination=${IMAGE_NAME}:latest \
              --verbosity=debug
          '''
        }
      }
    }

    stage('GitOps update') {
      steps {
        withCredentials([string(credentialsId: GITHUB_PAT_ID, variable: 'GH_PAT')]) {
          sh '''
            git clone ${GITOPS_REPO} gitops-tmp
            cd gitops-tmp
            git config user.name  "CI Bot"
            git config user.email "ci@socialdevs.dev"
            git remote set-url origin https://x-access-token:${GH_PAT}@github.com/vhgalvez/socialdevs-gitops.git

            sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" "${GITOPS_PATH}"
            git add "${GITOPS_PATH}"

            if git diff --cached --quiet; then
              echo "[INFO] No hay cambios en el manifiesto."
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
    success {
      echo '✅ Pipeline finalizado con éxito'
    }
    failure {
      echo '❌ Error en el pipeline'
    }
  }
}