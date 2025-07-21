// Jenkinsfile – versión final 🎉
//
// ▸ Requisitos en Jenkins
//   • PodTemplate “default” con contenedores:
//       – nodejs  : node:18‑alpine
//       – kaniko  : gcr.io/kaniko-project/executor:v1.23.0-debug
//   • Secret  dockerhub-config  montado en /kaniko/.docker
//   • Credencial **Username/Password** con ID github-ci-token
//       – Username → cualquier texto (p. ej. “github-ci”)
//       – Password → PAT de GitHub con scope repo
//--------------------------------------------------------------------------

pipeline {
  /* ───────────── 1. Agente Kubernetes ───────────────────────────── */
  agent {
    kubernetes {
      label 'default'           // ← coincide con JCasC
      defaultContainer 'nodejs' // ← contenedor base
    }
  }

  /* ───────────── 2. Variables globales ─────────────────────────── */
  environment {
    IMAGE_NAME  = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG   = "${BUILD_NUMBER}"
    GITOPS_REPO = 'https://github.com/vhgalvez/socialdevs-gitops.git'
    GITOPS_PATH = 'apps/socialdevs-frontend/deployment.yaml'
    GITHUB_PAT  = 'github-ci-token'         // ← ID de la credencial
  }

  /* ───────────── 3. Stages del pipeline ────────────────────────── */
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
          /*  ───── Usa helper Git para no exponer el token en la URL ───── */
          withCredentials([
            usernamePassword(
              credentialsId: GITHUB_PAT,
              usernameVariable: 'GH_USER',
              passwordVariable: 'GH_PAT')
          ]) {
            sh '''
              # instala git si hace falta (Alpine ~5 MB)
              command -v git >/dev/null 2>&1 || apk add --no-cache git

              # helper que inyecta usuario/token a cualquier URL https://github.com/…
              git config --global credential.helper '!f() { 
                  echo "username=${GH_USER}";
                  echo "password=${GH_PAT}";
              }; f'

              git clone --depth 1 ${GITOPS_REPO} gitops-tmp
              cd gitops-tmp
              git config user.email "ci@socialdevs.dev"
              git config user.name  "CI Bot"

              sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" ${GITOPS_PATH}
              git add ${GITOPS_PATH}
              git commit -m "🔄 Actualiza a ${IMAGE_NAME}:${IMAGE_TAG}" || echo "Sin cambios"

              # push usando el helper (no se ve el token)
              git push origin HEAD:main
            '''
          }
        }
      }
    }
  }

  /* ───────────── 4. Post‑build ──────────────────────────────────── */
  post {
    success { echo '✅ Pipeline OK' }
    failure { echo '❌ Pipeline FALLÓ' }
  }
}