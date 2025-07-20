// Jenkinsfile
pipeline {
  agent {
    kubernetes {
      label 'default'              // ← Debe coincidir con tu plantilla JCasC
      defaultContainer 'nodejs'    // ← Para las etapas con Node
    }
  }

  environment {
    IMAGE_NAME     = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG      = "${BUILD_NUMBER}"
    GITOPS_REPO    = 'https://github.com/vhgalvez/socialdevs-gitops.git'
    GITOPS_PATH    = 'apps/socialdevs-frontend/deployment.yaml'
    GITHUB_PAT_ID  = 'github-ci-token'   // ← ID de la credencial tipo "string"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Test') {
      steps {
        container('nodejs') {
          sh '''
            npm ci --registry=https://registry.npmmirror.com
            npm test
          '''
        }
      }
    }

    stage('Build & Push (Kaniko)') {
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \
              --dockerfile=Dockerfile \
              --context=dir://${WORKSPACE} \
              --destination=${IMAGE_NAME}:${IMAGE_TAG} \
              --destination=${IMAGE_NAME}:latest \
              --verbosity=info --skip-tls-verify
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
            git config user.email "ci@socialdevs.dev"
            git config user.name  "CI Bot"
            sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" ${GITOPS_PATH}
            git add ${GITOPS_PATH}
            git commit -m "🔄 Actualiza a ${IMAGE_NAME}:${IMAGE_TAG}" || echo "No hay cambios"
            git push https://x-access-token:${GH_PAT}@github.com/vhgalvez/socialdevs-gitops.git HEAD:main
          '''
        }
      }
    }
  }

  post {
    success {
      echo '✅ Pipeline OK'
    }
    failure {
      echo '❌ Pipeline FALLÓ'
    }
  }
}