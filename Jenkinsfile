// Jenkinsfile – GitOps frontend (agente Kubernetes heredado)
// ───────────────────────────────────────────────────────────
pipeline {

  /* 1️⃣ Agente */
  agent {
    kubernetes {
      inheritFrom 'gitops-agent'      // ⬅️ ya no usamos 'label'
      defaultContainer 'nodejs'
    }
  }

  /* 2️⃣ Variables */
  environment {
    IMAGE_NAME   = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG    = "${BUILD_NUMBER}"
    GITOPS_REPO  = 'https://github.com/vhgalvez/socialdevs-gitops.git'
    GITOPS_PATH  = 'apps/socialdevs-frontend/deployment.yaml'
    GITHUB_PAT   = credentials('github-ci-token')   // nueva sintaxis
  }

  /* 3️⃣ Stages */
  stages {

    stage('Checkout código') {
      steps { checkout scm }
    }

    stage('Tests unitarios') {
      steps {
        sh '''
          npm ci --registry=https://registry.npmmirror.com
          npm test
        '''
      }
    }

    stage('Build + Push imagen (Kaniko)') {
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

    stage('GitOps commit & push') {
      steps {
        sh '''
          # Instala Git si es necesario (alpine)
          command -v git >/dev/null 2>&1 || apk add --no-cache git curl

          # Verifica que el PAT es válido (200 OK)
          if [ "$(curl -s -o /dev/null -w '%{http_code}' \
                 -H "Authorization: token ${GITHUB_PAT}" \
                 https://api.github.com/user)" != "200" ]; then
              echo "❌ PAT inválido o revocado"; exit 1
          fi

          # Clona el repo con el PAT incrustado
          GIT_URL="https://x-access-token:${GITHUB_PAT}@github.com/vhgalvez/socialdevs-gitops.git"
          git clone --depth 1 "$GIT_URL" gitops-tmp
          cd gitops-tmp

          git config user.email "ci@socialdevs.dev"
          git config user.name  "CI Bot"

          # Actualiza el manifiesto de la imagen
          sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" ${GITOPS_PATH}
          git add ${GITOPS_PATH}
          git commit -m "🔄 Actualiza a ${IMAGE_NAME}:${IMAGE_TAG}" || echo "Sin cambios"

          # Push (usando la URL ya con token)
          git push "$GIT_URL" HEAD:main
        '''
      }
    }
  }

  /* 4️⃣ Post‑build */
  post {
    success { echo '✅ Pipeline OK' }
    failure { echo '❌ Pipeline FALLÓ' }
  }
}