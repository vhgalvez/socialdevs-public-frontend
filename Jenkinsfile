// Jenkinsfile – versión 100 % operativa
//
// ▸ Requisitos en el lado de Jenkins
//   • PodTemplate “default” con contenedores:
//       – nodejs  : node:18‑alpine
//       – kaniko  : gcr.io/kaniko-project/executor:v1.23.0-debug
//   • Secret  dockerhub-config  montado en /kaniko/.docker
//   • Credencial **Username + Password** con ID `github-ci-token`
//       – Username → cualquier texto (p. ej. `github-ci`)
//       – Password → tu PAT de GitHub con scope `repo`
// ---------------------------------------------------------------------------

pipeline {
  /* ────────────────── 1. Agente Kubernetes ──────────────────── */
  agent {
    kubernetes {
      label            'default'      // ← debe coincidir con tu JCasC
      defaultContainer 'nodejs'       // ← contenedor por defecto
    }
  }

  /* ────────────────── 2. Variables globales ─────────────────── */
  environment {
    IMAGE_NAME  = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG   = "${BUILD_NUMBER}"
    GITOPS_REPO = 'https://github.com/vhgalvez/socialdevs-gitops.git'
    GITOPS_PATH = 'apps/socialdevs-frontend/deployment.yaml'
    GITHUB_CREDS = 'github-ci-token'   // ← ID de la credencial (user/pass)
  }

  /* ────────────────── 3. Stages del pipeline ────────────────── */
  stages {

    stage('Checkout') {
      steps { checkout scm }
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
        container('nodejs') {
          /* Instalamos git (≃5 MB) y configuramos helper de credenciales
             que inyecta el PAT sin exponerlo en la URL */
          withCredentials([
            usernamePassword(credentialsId: GITHUB_CREDS,
                             usernameVariable: 'GH_USER',
                             passwordVariable: 'GH_PAT')
          ]) {
            sh '''
              # Instala git en Alpine si no existe
              command -v git >/dev/null 2>&1 || apk add --no-cache git

              # Helper para autenticar cualquier push/clone via HTTPS
              git config --global credential.helper '!f() { \
                echo "username=${GH_USER}"; \
                echo "password=${GH_PAT}"; \
              }; f'

              git clone --depth 1 ${GITOPS_REPO} gitops-tmp
              cd gitops-tmp
              git config user.email "ci@socialdevs.dev"
              git config user.name  "CI Bot"

              sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" ${GITOPS_PATH}
              git add ${GITOPS_PATH}
              git commit -m "🔄 Actualiza a ${IMAGE_NAME}:${IMAGE_TAG}" || echo "Sin cambios"

              git push origin HEAD:main
            '''
          }
        }
      }
    }
  }

  /* ────────────────── 4. Post‑build ─────────────────────────── */
  post {
    success { echo '✅ Pipeline OK'  }
    failure { echo '❌ Pipeline FALLÓ' }
  }
}