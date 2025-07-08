pipeline {
  agent any

  environment {
    IMAGE_NAME = "vhgalvez/socialdevs-public-frontend"
    IMAGE_TAG = "${BUILD_NUMBER}"
    GITOPS_REPO = "https://github.com/vhgalvez/socialdevs-gitops.git"
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

    stage('🐳 Construir imagen Docker') {
      steps {
        script {
          sh """
            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
          """
        }
      }
    }

    stage('🔐 Login y Push a Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh """
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker push ${IMAGE_NAME}:latest
          """
        }
      }
    }

    stage('🚀 Actualizar GitOps') {
      steps {
        sh """
          git config --global user.name "CI Bot"
          git config --global user.email "ci@socialdevs.dev"
          rm -rf socialdevs-gitops
          git clone ${GITOPS_REPO}
          cd socialdevs-gitops/apps/frontend
          sed -i "s|image: vhgalvez/socialdevs-public-frontend:.*|image: vhgalvez/socialdevs-public-frontend:${IMAGE_TAG}|" deployment.yaml
          git commit -am "🔄 Update frontend image to ${IMAGE_TAG}"
          git push https://github.com/vhgalvez/socialdevs-gitops.git main
        """
      }
    }
  }

  post {
    success {
      echo "✅ Build exitoso → Imagen: ${IMAGE_NAME}:${IMAGE_TAG} desplegada vía GitOps"
    }
    failure {
      echo "❌ Error en el pipeline"
    }
  }
}