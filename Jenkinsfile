pipeline {
  agent {
    kubernetes {
      //  ⬇️  IMPORTANTE: que coincida con el label del cloud (o quítalo en ambos)
      label 'jenkins-agent'

      yaml """
apiVersion: v1
kind: Pod
spec:
  restartPolicy: Never
  volumes:
    - name: kaniko-secret
      secret:
        secretName: dockerhub-config
    - name: workspace
      emptyDir: {}
  containers:
    # Kaniko
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command: ["/busybox"]
      args: ["sleep", "infinity"]
      volumeMounts:
        - name: kaniko-secret
          mountPath: /kaniko/.docker
        - name: workspace
          mountPath: /home/jenkins/agent

    # Node
    - name: nodejs
      image: node:18.20.4-alpine
      command: ["sh", "-c"]
      args: ["while true; do sleep 30; done"]
      tty: true
      volumeMounts:
        - name: workspace
          mountPath: /home/jenkins/agent
"""
      defaultContainer 'nodejs'
    }
  }

  environment {
    IMAGE_NAME  = 'vhgalvez/socialdevs-public-frontend'
    IMAGE_TAG   = "${BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') { steps { checkout scm } }

    stage('Build & Push') {
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \
              --dockerfile=Dockerfile \
              --context=dir:///home/jenkins/agent \
              --destination=${IMAGE_NAME}:${IMAGE_TAG} \
              --destination=${IMAGE_NAME}:latest
          '''
        }
      }
    }
  }
}