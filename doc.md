✅ PASO 1: Añadir el repositorio GitOps a ArgoCD
Puedes hacerlo desde el dashboard web o por línea de comandos. Te recomiendo la CLI:

bash
Copiar
Editar
argocd repo add https://github.com/vhgalvez/socialdevs-gitops \
  --username <tu_usuario> \
  --password <tu_token_personal_github>
🔐 Usa un GitHub Personal Access Token como contraseña, no la contraseña de tu cuenta.

✅ PASO 2: Crear la aplicación en ArgoCD
bash
Copiar
Editar
argocd app create socialdevs-frontend \
  --repo https://github.com/vhgalvez/socialdevs-gitops \
  --path apps/socialdevs-frontend/overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --directory-recurse
✅ PASO 3: Sincronizarla por primera vez
bash
Copiar
Editar
argocd app sync socialdevs-frontend
Esto forzará la sincronización inicial y desplegará el frontend si el manifiesto está bien.

(Opcional) Ver estado
bash
Copiar
Editar
argocd app list
argocd app get socialdevs-frontend


🧱 1. Crear las credenciales necesarias
A. Docker Hub
Ve a: Jenkins > Manage Jenkins > Credentials > (global)

Añade una Username + Password

ID sugerido: dockerhub

B. GitHub (para push a socialdevs-gitops)
Añade un Personal Access Token de GitHub como tipo Username + Password

ID sugerido: git-creds

🧪 2. Crear un nuevo pipeline para el frontend
Ve a Jenkins > New Item

Nombre: socialdevs-frontend-pipeline

Tipo: Pipeline

En la sección Pipeline > Definition, selecciona Pipeline script from SCM

SCM: Git

Repositorio: https://github.com/vhgalvez/socialdevs-public-frontend.git

Credentials: (ninguna si es público)

Branch: main

Script Path: Jenkinsfile (ya está en el repo)

🔧 3. Asegúrate que el Jenkinsfile contenga lo siguiente
Jenkinsfile (en socialdevs-public-frontend/Jenkinsfile)
groovy
Copiar
Editar
pipeline {
  agent any

  environment {
    IMAGE = "vhgalvez/socialdevs-public-frontend:latest"
  }

  stages {
    stage('Checkout') {
      steps {
        git 'https://github.com/vhgalvez/socialdevs-public-frontend.git'
      }
    }

    stage('Build Docker Image') {
      steps {
        sh "docker build -t $IMAGE ."
      }
    }

    stage('Push to DockerHub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
          sh "docker push $IMAGE"
        }
      }
    }

    stage('Update GitOps repo') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'git-creds', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
          sh '''
            git config --global user.email "jenkins@ci.com"
            git config --global user.name "Jenkins CI"

            git clone https://$GIT_USER:$GIT_PASS@github.com/vhgalvez/socialdevs-gitops.git
            cd socialdevs-gitops/apps/socialdevs-frontend/overlays/dev
            sed -i "s|image: .*|image: vhgalvez/socialdevs-public-frontend:latest|" deployment.yaml
            git commit -am "CI: update image tag"
            git push
          '''
        }
      }
    }
  }
}
✅ 4. Prueba completa del pipeline
Haz git push a tu repositorio socialdevs-public-frontend

Jenkins construirá la imagen → la subirá → actualizará deployment.yaml en el GitOps repo

ArgoCD detectará el cambio y aplicará automáticamente el nuevo despliegue




✅ FLUJO COMPLETO CI/CD con Jenkins + ArgoCD + GitOps
1. Repos públicos ya listos
frontend: https://github.com/vhgalvez/socialdevs-public-frontend

gitops: https://github.com/vhgalvez/socialdevs-gitops

Docker: https://hub.docker.com/r/vhgalvez/socialdevs-public-frontend

2. Pipeline en Jenkins (public + GitOps)
Ya lo tienes casi perfecto. Te dejo la versión final ajustada para ArgoCD:

groovy
Copiar
Editar
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
3. Configurar ArgoCD App (si no lo hiciste aún)
yaml
Copiar
Editar
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: socialdevs-frontend
  namespace: argocd
spec:
  destination:
    name: ''
    namespace: frontend
    server: 'https://kubernetes.default.svc'
  source:
    repoURL: 'https://github.com/vhgalvez/socialdevs-gitops'
    targetRevision: main
    path: apps/frontend
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
Aplica con:

bash
Copiar
Editar
kubectl apply -f socialdevs-frontend-app.yaml
4. Final: ArgoCD despliega automáticamente el nuevo frontend
Jenkins construye y sube la imagen con nuevo tag

Jenkins actualiza deployment.yaml en el repo GitOps

ArgoCD detecta el cambio y aplica automáticamente el despliegue




__
🔄 FLUJO CI/CD COMPLETO: GitHub → Jenkins → Docker Hub → ArgoCD → K3s
text
Copiar
Editar
          [ DEV - Código fuente ]
                   │
            Git Push a GitHub
           ┌─────────────────────┐
           │ socialdevs-public-  │
           │ frontend (Vue.js)   │
           └─────────────────────┘
                   │
                   ▼
           Jenkins ejecuta CI Pipeline
           ┌────────────────────────────┐
           │ Jenkinsfile:               │
           │  1. docker build           │
           │  2. docker push            │
           │  3. update GitOps repo     │
           └────────────────────────────┘
                   │
                   ▼
           Docker Hub (registro)
           ┌─────────────────────┐
           │ vhgalvez/socialdevs │
           └─────────────────────┘
                   │
                   ▼
        Git Push a socialdevs-gitops
        ┌──────────────────────────────┐
        │ ArgoCD detecta cambio en     │
        │ deployment.yaml (imagen nueva)│
        └──────────────────────────────┘
                   │
                   ▼
         ArgoCD sincroniza en:
      ┌─────────────────────┐
      │    [K3d Local]      │ ← entorno test
      └─────────────────────┘
                   │
                   ▼
      ┌─────────────────────┐
      │    [K3s Producción]  │ ← tu servidor físico con Traefik, PVCs, NFS, etc.
      └─────────────────────┘
📂 Repositorios involucrados
Repositorio GitHub	Descripción
socialdevs-public-frontend	Vue.js + Dockerfile + Jenkinsfile
socialdevs-gitops	Kustomize: deployment.yaml, service.yaml, ingress.yaml
argocd-bootstrap_local_k3d	Instala y configura ArgoCD en k3d (para testing local)
Jenkins_k3d_local	Instala Jenkins con Helm en K3d, usa jenkins-values.yaml

🧪 Flujo de Testing en k3d
Jenkins se ejecuta en un pod de k3d usando Helm.

El agente DinD construye la imagen con Docker in Docker.

Se sube la imagen a Docker Hub.

Jenkins actualiza deployment.yaml en socialdevs-gitops.

ArgoCD sincroniza y despliega el pod en k3d.

🚀 Flujo de Producción en K3s
Validas el build en k3d.

Si está todo correcto, haces push/tag (o cherry-pick) en rama main de producción.

Jenkins vuelve a ejecutar build/push/update en el GitOps repo.

ArgoCD en el cluster real (K3s) detecta el cambio y despliega automáticamente en tu servidor físico.

✅ Ventajas del Flujo
Ventaja	Detalle
🔁 GitOps puro	Jenkins no toca K8s directamente. ArgoCD hace el despliegue.
🔐 Seguridad	Jenkins no necesita acceso al cluster. Solo ArgoCD tiene permisos.
🧪 Separación test/producción	k3d permite validar todo antes de desplegar en tu K3s productivo.
📦 Contenedores versionados	Imágenes con tags únicos por BUILD_NUMBER o commit SHA
🔄 Idempotencia y trazabilidad	ArgoCD gestiona el estado deseado en Git (declarativo)


___________
✅ Arquitectura CI/CD GitOps completa
🧱 Infraestructura
Componente	Tecnología	Función
Clúster Local	K3d + ArgoCD + Jenkins	Entorno de pruebas
Clúster Producción	K3s + Flatcar Linux	Entorno estable y seguro
CI/CD	Jenkins (en K3d)	Pipelines de build, test, push y GitOps update
Registro de imágenes	DockerHub (vhgalvez/*)	Almacenamiento de imágenes versionadas
Código fuente	GitHub (socialdevs-public-frontend)	Microservicio frontend
GitOps repo	GitHub (socialdevs-gitops)	Declarativo: manifiestos K8s actualizados por Jenkins
CD	ArgoCD (en K3d/K3s)	Sincronización automática al clúster

🔁 Flujo CI/CD paso a paso
plaintext
Copiar
Editar
              ┌────────────┐
              │ Desarrollador │
              └─────┬──────┘
                    │ Push código (frontend)
                    ▼
         ┌──────────────────────────┐
         │ GitHub: socialdevs-public-frontend │
         └────────────┬─────────────┘
                      ▼
           ┌───────────────────┐
           │ Jenkins Pipeline  │
           └───────────────────┘
     (1) Checkout del repo `frontend`
     (2) npm install + test unitarios (Vitest)
     (3) docker build → `vhgalvez/socialdevs-public-frontend:<build>`
     (4) docker push a DockerHub
     (5) git clone `socialdevs-gitops`
     (6) update de `deployment.yaml` con nueva imagen
     (7) git commit + push

                      ▼
         ┌────────────────────────┐
         │ GitHub: socialdevs-gitops │
         └────────────┬─────────────┘
                      ▼
           ┌────────────────────┐
           │ ArgoCD (K3d / K3s) │
           └────────────────────┘
     (8) Detecta cambio en manifiesto
     (9) Aplica rollout con nueva imagen
    (10) Clúster se actualiza automáticamente
🛠️ Detalles técnicos por etapa
Jenkins
Corre en K3d.

Usa /var/run/docker.sock o Kaniko.

Tiene credenciales (dockerhub-credentials, github-ci-token).

Jenkinsfile contiene podTemplate con docker, nodejs, jnlp.

DockerHub
Imagen: vhgalvez/socialdevs-public-frontend

Etiquetas: :latest, :<build_number>

GitOps (socialdevs-gitops)
Ejemplo de deployment.yaml:

yaml
Copiar
Editar
containers:
  - name: app
    image: vhgalvez/socialdevs-public-frontend:123
ArgoCD
Apunta al repo socialdevs-gitops

Sincroniza automáticamente (auto-sync + auto-prune opcional)

Puede tener ApplicationSet si despliegas a múltiples entornos