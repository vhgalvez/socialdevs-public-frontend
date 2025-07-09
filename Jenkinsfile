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
      image: docker:25.0.3-cli
      command:
        - sh
        - -c
        - |
          echo 'Esperando a que Docker esté disponible...'
          while ! docker info >/dev/null 2>&1; do
            sleep 2
          done
          echo 'Docker listo.'
          sleep 99d
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
  }

  stages {
    stage('🐳 Build Docker Image') {
      steps {
        sh """
          docker version
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
        """
      }
    }

    stage('📤 Push Docker (si hay credencial)') {
      steps {
        script {
          env.DOCKER_PUSH_DONE = 'false'
          try {
            withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                              usernameVariable: 'DOCKER_USER',
                                              passwordVariable: 'DOCKER_PASS')]) {
              sh '''
                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                docker push ${IMAGE_NAME}:${IMAGE_TAG}
                docker push ${IMAGE_NAME}:latest
              '''
              env.DOCKER_PUSH_DONE = 'true'
            }
          } catch (ignored) {
            echo "⚠️  Credencial 'dockerhub' no encontrada, se omite el push"
          }
        }
      }
    }

    stage('🚀 GitOps: Update image tag') {
      when {
        expression { env.DOCKER_PUSH_DONE == 'true' }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'git-creds',
                                          usernameVariable: 'GIT_USER',
                                          passwordVariable: 'GIT_PASS')]) {
          sh '''
            git config --global user.email "ci@socialdevs.dev"
            git config --global user.name  "CI Bot"
            rm -rf gitops
            git clone https://${GIT_USER}:${GIT_PASS}@github.com/vhgalvez/socialdevs-gitops.git gitops
            cd gitops
            sed -i "s|image: vhgalvez/socialdevs-public-frontend:.*|image: vhgalvez/socialdevs-public-frontend:${IMAGE_TAG}|" ${GITOPS_PATH}
            git add ${GITOPS_PATH}
            git commit -m "🔄 Update frontend image to ${IMAGE_TAG}"
            git push origin main
          '''
        }
      }
    }
  }

  post {
    success { echo '✅ Pipeline completo: imagen construida y GitOps actualizado' }
    failure { echo '❌ Error en el pipeline' }
  }
}