pipeline {
  agent {
    kubernetes {
      yaml """
      # … (tu YAML del pod idéntico, recortado por brevedad)
      """
      defaultContainer 'docker'
    }
  }

  /* ========= VARIABLES ========= */
  environment {
    IMAGE_NAME  = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG   = "${BUILD_NUMBER}"
    GITOPS_REPO = 'https://github.com/vhgalvez/socialdevs-gitops.git'
    GITOPS_PATH = 'apps/socialdevs-frontend/deployment.yaml'

    DOCKER_CRED_ID = 'dockerhub-credentials'
    GITHUB_PAT_ID  = 'github-pat'        // <-- PAT guardado como Secret-Text
  }

  /* ========= STAGES ========= */
  stages {

    stage('🧾 Checkout código') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: '*/main']],
          userRemoteConfigs: [[url: 'https://github.com/vhgalvez/socialdevs-public-frontend.git']]
        ])
      }
    }

    stage('🧪 Test') {
      steps {
        container('nodejs') {
          sh '''
            npm config set registry https://registry.npmmirror.com
            npm ci
            npm run test
          '''
        }
      }
    }

    stage('🐳 Build & Tag') {
      steps {
        sh '''
          timeout 60 sh -c 'until docker info >/dev/null 2>&1; do sleep 2; done'
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
        '''
      }
    }

    stage('📤 Push a Docker Hub') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: DOCKER_CRED_ID,
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS')])
        {
          sh '''
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker push ${IMAGE_NAME}:latest
          '''
        }
      }
    }

    stage('🚀 GitOps update') {
      steps {
        /* PAT solo como password, vía Secret-Text */
        withCredentials([string(credentialsId: GITHUB_PAT_ID, variable: 'GH_PAT')]) {
          sh '''
            set -e
            # Clonamos SÓLO lectura (no hace falta token todavía)
            git clone https://github.com/vhgalvez/socialdevs-gitops.git gitops-tmp
            cd gitops-tmp
            git config user.name  "CI Bot"
            git config user.email "ci@socialdevs.dev"

            # Re-escribimos remote para push con PAT
            git remote set-url origin https://x-access-token:${GH_PAT}@github.com/vhgalvez/socialdevs-gitops.git

            # Actualizamos manifest
            sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" ${GITOPS_PATH}
            git add ${GITOPS_PATH}
            git diff --cached --quiet || git commit -m "🔄 Actualiza a ${IMAGE_NAME}:${IMAGE_TAG}"
            git push origin main
          '''
        }
      }
    }
  }

  /* ========= POST ========= */
  post {
    success { echo '✅ Pipeline finalizado con éxito' }
    failure { echo '❌ Error en el pipeline' }
  }
}