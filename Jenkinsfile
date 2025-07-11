pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins/role: docker-builder
spec:
  volumes:
    - name: workspace-volume
      emptyDir: {}
  containers:
    - name: dind-daemon
      image: docker:25.0.3-dind
      securityContext:
        privileged: true
      env:
        - name: DOCKER_TLS_CERTDIR
          value: ""
      command: ["dockerd"]
      args:
        - "--host=tcp://0.0.0.0:2375"
        - "--host=unix:///var/run/docker.sock"
      ports:
        - containerPort: 2375
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent

    - name: docker
      image: vhgalvez/docker-git-cli:25.0.3
      command: ["cat"]
      tty: true
      env:
        - name: DOCKER_HOST
          value: tcp://localhost:2375
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent

    - name: jnlp
      image: jenkins/inbound-agent:3283.v92c105e0f819-4
      env:
        - name: JENKINS_AGENT_WORKDIR
          value: /home/jenkins/agent
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent
  restartPolicy: Never
"""
      defaultContainer 'docker'
    }
  }

  environment {
    IMAGE_NAME  = "vhgalvez/socialdevs-public-frontend"
    IMAGE_TAG   = "${BUILD_NUMBER}"
    GITOPS_REPO = "https://github.com/vhgalvez/socialdevs-gitops.git"
    GITOPS_PATH = "apps/socialdevs-frontend/deployment.yaml"
    DOCKER_REGISTRY_CREDENTIALS_ID = 'dockerhub-credentials'
  }

  stages {
    stage('🧾 Checkout código') {
      steps { checkout scm }
    }

    stage('🐳 Build Docker') {
      steps {
        sh '''
          echo "[INFO] Esperando Docker daemon…"
          timeout 60 bash -c 'until docker info >/dev/null 2>&1; do sleep 2; done'
          echo "[INFO] Docker listo."

          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
        '''
      }
    }

    stage('📤 Push a Docker Hub') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: DOCKER_REGISTRY_CREDENTIALS_ID,
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker push ${IMAGE_NAME}:latest
          '''
        }
      }
    }

    stage('🚀 GitOps: actualiza manifiesto') {
      steps {
        git branch: 'main', url: GITOPS_REPO

        sh '''
          sed -i 's|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|' ${GITOPS_PATH}

          git config user.email 'ci@socialdevs.dev'
          git config user.name  'CI Bot'
          git commit -am "🔄 ${IMAGE_NAME}:${IMAGE_TAG}"
          git push origin main
        '''
      }
    }
  }

  post {
    success { echo '✅ Pipeline finalizado con éxito' }
    failure { echo '❌ Error en el pipeline' }
  }
}