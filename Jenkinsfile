pipeline {
  agent any

  environment {
    IMAGE_NAME = "vhgalvez/socialdevs-public-frontend"
    IMAGE_TAG = "${BUILD_NUMBER}" // Usamos el número de build para versionar
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

    stage('🚀 (Opcional) Actualizar GitOps') {
      when {
        expression { return false }  // Cambia a `true` si quieres hacer push a gitops automáticamente
      }
      steps {
        echo "Aquí podrías actualizar el manifiesto kustomize con la nueva versión: ${IMAGE_TAG}"
        // Aquí podrías usar sed + git para actualizar el image tag en tu repositorio GitOps
      }
    }

  }

  post {
    success {
      echo "✅ Build completado correctamente. Imagen: ${IMAGE_NAME}:${IMAGE_TAG}"
    }
    failure {
      echo "❌ Error durante el pipeline"
    }
  }
}
