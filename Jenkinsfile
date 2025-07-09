pipeline {
  agent {
    kubernetes { /* …tu YAML del podTemplate sin cambios… */ }
  }

  environment {
    IMAGE_NAME  = "vhgalvez/socialdevs-public-frontend"
    IMAGE_TAG   = "${BUILD_NUMBER}"
    GITOPS_REPO = "https://github.com/vhgalvez/socialdevs-gitops.git"
    GITOPS_PATH = "apps/socialdevs-frontend/deployment.yaml"
  }

  stages {
    stage('🐳 Esperar Docker Daemon') { /* …sin cambios… */ }

    stage('🐳 Build Docker Image') { /* …sin cambios… */ }

    stage('📤 Push Docker (si hay credencial)') {
      steps {
        script {
          def pushed = false
          try {
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
              pushed = true
            }
          } catch (e) {
            echo "⚠️  Credencial 'dockerhub' no encontrada: se omite el push"
          }
          env.DOCKER_PUSH_DONE = pushed.toString()
        }
      }
    }

    stage('🚀 GitOps: Update image tag') {
      when {
        expression { return env.DOCKER_PUSH_DONE == 'true' }
      }
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
            sed -i "s|image: vhgalvez/socialdevs-public-frontend:.*|image: vhgalvez/socialdevs-public-frontend:${IMAGE_TAG}|" ${GITOPS_PATH}
            git add ${GITOPS_PATH}
            git commit -m "🔄 Update frontend image to ${IMAGE_TAG}"
            git push origin main
          '''
        }
      }
    }
  }

  post {
    success { echo '✅ Pipeline completo: imagen construida y GitOps actualizado' }
    failure { echo '❌ Error en el pipeline' }
  }
}
