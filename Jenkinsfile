// Jenkinsfile (versión corregida)

/* ------------------------------------------------------------------------
 *  Requisitos previos en tu Cloud de Jenkins
 *  — PodTemplate “default” con contenedores:
 *      · nodejs  : node:18‑alpine
 *      · kaniko  : gcr.io/kaniko-project/executor:v1.23.0-debug
 *  — Secret dockerhub-config montado en /kaniko/.docker
 *  — Credencial string ‘github-ci-token’ (PAT de GitHub)
 * --------------------------------------------------------------------- */

pipeline {
  /* ──────────────── 1. Agente Kubernetes ─────────────────────────── */
  agent {
    kubernetes {
      label 'default'              // → igual que en JCasC
      defaultContainer 'nodejs'    // → contenedor base para los steps
    }
  }

  /* ──────────────── 2. Variables globales ────────────────────────── */
  environment {
    IMAGE_NAME    = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG     = "${BUILD_NUMBER}"
    GITOPS_REPO   = 'https://github.com/vhgalvez/socialdevs-gitops.git'
    GITOPS_PATH   = 'apps/socialdevs-frontend/deployment.yaml'
    GITHUB_PAT_ID = 'github-ci-token'
  }

  /* ─────────────────── 3. Stages del pipeline ────────────────────── */
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
        /*  Usamos el contenedor nodejs, instalamos git “on‑the‑fly”.
            Son sólo ~5 MB y evita crear otra imagen */
        container('nodejs') {
          withCredentials([string(credentialsId: GITHUB_PAT_ID, variable: 'GH_PAT')]) {
            sh '''
              # --- instala git en Alpine si no existe
              command -v git >/dev/null 2>&1 || apk add --no-cache git

              git clone --depth 1 ${GITOPS_REPO} gitops-tmp
              cd gitops-tmp
              git config user.email "ci@socialdevs.dev"
              git config user.name  "CI Bot"

              sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" ${GITOPS_PATH}
              git add ${GITOPS_PATH}
              git commit -m "🔄 Actualiza a ${IMAGE_NAME}:${IMAGE_TAG}" || echo "Sin cambios"
              git push https://x-access-token:${GH_PAT}@github.com/vhgalvez/socialdevs-gitops.git HEAD:main
            '''
          }
        }
      }
    }
  }

  /* ─────────────────── 4. Post‑build notifications ───────────────── */
  post {
    success { echo '✅ Pipeline OK'     }
    failure { echo '❌ Pipeline FALLÓ' }
  }
}