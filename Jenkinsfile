pipeline {
  agent any

  environment {
    IMAGE_NAME = "vhgalvez/socialdevs-public-frontend"
    IMAGE_TAG = "${BUILD_NUMBER}"
    GITOPS_REPO = "https://github.com/vhgalvez/socialdevs-gitops.git"
    GITOPS_PATH = "apps/frontend/deployment.yaml"
  }

  stages {
    stage('📦 Instalar dependencias') {
      steps {
        sh 'npm install'
      }
    }

    stage('🛠️ Compilar Frontend') {
      steps {
        sh 'npm run build'
      }
    }

    stage('🐳 Build & Push Docker') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh """
            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest

            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker push ${IMAGE_NAME}:latest
          """
        }
      }
    }

    stage('🚀 GitOps: Update image tag') {
      steps {
        withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
          sh """
            git config --global user.name "CI Bot"
            git config --global user.email "ci@socialdevs.dev"
            rm -rf gitops && git clone https://$GITHUB_TOKEN@github.com/vhgalvez/socialdevs-gitops.git gitops
            cd gitops
            sed -i 's|image: vhgalvez/socialdevs-public-frontend:.*|image: vhgalvez/socialdevs-public-frontend:${IMAGE_TAG}|' ${GITOPS_PATH}
            git commit -am "🔄 Update frontend image to ${IMAGE_TAG}"
            git push origin main
          """
        }
      }
    }
  }

  post {
    success {
      echo "✅ Pipeline completo: Imagen publicada y GitOps actualizado"
    }
    failure {
      echo "❌ Error en el pipeline"
    }
  }
}