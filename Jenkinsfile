// Jenkinsfile
// ────────────────────────────────────────────────────────────────────────
// Jenkinsfile  – GitOps frontend (token PAT guardado como Secret‑text)
// ------------------------------------------------------------------------
// • PodTemplate “default” con contenedores:
//     · nodejs  : node:18‑alpine
//     · kaniko  : gcr.io/kaniko-project/executor:v1.23.0-debug
// • Secret dockerhub-config → /kaniko/.docker
// • Credencial *Secret text*  (ID github-ci-token) con tu PAT
//   ↳ Ubícala en *System / Global* (no en la store de usuario)
// ------------------------------------------------------------------------

pipeline {
  /* ───────── 1. Agente Kubernetes ───────── */
  agent {
    kubernetes {
      label            'default'
      defaultContainer 'nodejs'
    }
  }

  /* ───────── 2. Variables globales ──────── */
  environment {
    IMAGE_NAME  = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG   = "${BUILD_NUMBER}"
    GITOPS_REPO = 'https://github.com/vhgalvez/socialdevs-gitops.git'
    GITOPS_PATH = 'apps/socialdevs-frontend/deployment.yaml'
    GITHUB_PAT_ID = 'github-ci-token'     // ← Secret‑text con el PAT
  }

  /* ───────── 3. Pipeline stages ─────────── */
  stages {

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Unit tests') {
      steps {
        container('nodejs') {
          sh '''
            npm ci --registry=https://registry.npmmirror.com
            npm test
          '''
        }
      }
    }

    stage('Build & push image (Kaniko)') {
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

    stage('GitOps commit & push') {
      steps {
        container('nodejs') {
          withCredentials([string(credentialsId: GITHUB_PAT_ID, variable: 'GH_PAT')]) {

            sh '''
              # instala git en Alpine si no existe
              command -v git >/dev/null 2>&1 || apk add --no-cache git

              # helper que suministra usuario + token para cualquier URL HTTPS
              git config --global credential.helper '!f() { \
                  echo "username=x-access-token"; \
                  echo "password=${GH_PAT}"; \
              }; f'

              # clona, modifica manifiesto y hace push
              git clone --depth 1 ${GITOPS_REPO} gitops-tmp
              cd gitops-tmp
              git config user.email "ci@socialdevs.dev"
              git config user.name  "CI Bot"

              sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" ${GITOPS_PATH}
              git add ${GITOPS_PATH}
              git commit -m "🔄 Actualiza a ${IMAGE_NAME}:${IMAGE_TAG}" || echo "Sin cambios"
              git push origin HEAD:main
            '''
          }
        }
      }
    }
  }

  /* ───────── 4. Post‑build ─────────────── */
  post {
    success { echo '✅ Pipeline OK'   }
    failure { echo '❌ Pipeline FALLÓ' }
  }
}