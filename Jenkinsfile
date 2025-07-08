
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'npm install'
                sh 'npm run build'
            }
        }
        stage('Docker Build & Push') {
            steps {
                sh 'docker build -t youruser/socialdevs-frontend:latest .'
                sh 'docker push youruser/socialdevs-frontend:latest'
            }
        }
    }
}
