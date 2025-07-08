pipeline {
  agent any

  environment {
    IMAGE_NAME  = "vhgalvez/socialdevs-public-frontend"
    IMAGE_TAG   = "${BUILD_NUMBER}"
    GITOPS_REPO = "https://github.com/vhgalvez/socialdevs-gitops.git"
    GITOPS_PATH = "apps/socialdevs-frontend/deployment.yaml"
  }

  stages {

    /* ───────────────────────────────────────────────
       🐳  Build & (opcional) Push Docker
       Si la credencial 'dockerhub' existe => push
       Si no existe => solo build local (no falla)
       ─────────────────────────────────────────────── */
    stage('🐳 Build Docker Image') {
      steps {
        sh """
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
        """
      }
    }

    stage('📤 Push Docker (si hay credencial)') {
      when {
        expression { 
          // Devuelve true solo si existe credencial con ID 'dockerhub'
          def creds = com.cloudbees.plugins.credentials.CredentialsProvider
                        .lookupCredentials(
                          com.cloudbees.plugins.credentials.common.StandardUsernameCredentials.class,
                          Jenkins.instance
                        )
          return creds.find { it.id == 'dockerhub' } != null
        }
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh """
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker push ${IMAGE_NAME}:latest
          """
        }
      }
    }

    /* ───────────────────────────────────────────────
       🚀  GitOps: Actualizar deployment.yaml
       ─────────────────────────────────────────────── */
    stage('🚀 GitOps: Update image tag') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'git-creds',
          usernameVariable: 'GIT_USER',
          passwordVariable: 'GIT_PASS'
        )]) {
          sh """
            git config --global user.email "ci@socialdevs.dev"
            git config --global user.name  "CI Bot"

            rm -rf gitops
            git clone https://${GIT_USER}:${GIT_PASS}@github.com/vhgalvez/socialdevs-gitops.git gitops
            cd gitops
            sed -i 's|image: vhgalvez/socialdevs-public-frontend:.*|image: vhgalvez/socialdevs-public-frontend:${IMAGE_TAG}|' ${GITOPS_PATH}
            git add ${GITOPS_PATH}
            git commit -m "🔄 Update frontend image to ${IMAGE_TAG}"
            git push origin main
          """
        }
      }
    }
  }

  post {
    success {
      echo "✅ Pipeline completo: imagen construida y GitOps actualizado"
    }
    failure {
      echo "❌ Error en el pipeline"
    }
  }
}