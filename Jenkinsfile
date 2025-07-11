controller:
  image:
    repository: jenkins/jenkins
    tag: "2.504.3-jdk17"
    pullPolicy: IfNotPresent

  admin:
    existingSecret: jenkins-admin
    userKey: jenkins-admin-user
    passwordKey: jenkins-admin-password

  containerEnv:
    - name: JENKINS_ADMIN_USER
      valueFrom:
        secretKeyRef:
          name: jenkins-admin
          key: jenkins-admin-user
    - name: JENKINS_ADMIN_PASSWORD
      valueFrom:
        secretKeyRef:
          name: jenkins-admin
          key: jenkins-admin-password
    - name: DOCKERHUB_USERNAME
      valueFrom:
        secretKeyRef:
          name: dockerhub-credentials
          key: username
    - name: DOCKERHUB_TOKEN
      valueFrom:
        secretKeyRef:
          name: dockerhub-credentials
          key: password
    - name: GITHUB_TOKEN
      valueFrom:
        secretKeyRef:
          name: github-ci-token
          key: token

  installPlugins:
    - kubernetes
    - workflow-aggregator
    - git
    - docker-workflow
    - docker-commons
    - blueocean
    - credentials
    - credentials-binding
    - configuration-as-code
    - plain-credentials

  JCasC:
    enabled: true
    defaultConfig: false
    configScripts:
      main: |
        jenkins:
          securityRealm:
            local:
              allowsSignup: false
              users:
                - id: "${JENKINS_ADMIN_USER}"
                  password: "${JENKINS_ADMIN_PASSWORD}"

          authorizationStrategy:
            loggedInUsersCanDoAnything:
              allowAnonymousRead: false

          clouds:
            - kubernetes:
                name: "kubernetes"
                serverUrl: "https://kubernetes.default"
                skipTlsVerify: true
                namespace: "jenkins"
                jenkinsUrl: "http://jenkins-local-k3d:8080"
                jenkinsTunnel: "jenkins-local-k3d-agent:50000"
                containerCap: 10
                connectTimeout: 5
                readTimeout: 15
                templates:
                  - name: "default"
                    label: "jenkins-agent"
                    nodeUsageMode: "NORMAL"
                    idleMinutes: 1
                    containers:
                      - name: jnlp
                        image: "jenkins/inbound-agent:alpine"
                        args: "${computer.jnlpmac} ${computer.name}"
                        ttyEnabled: true
                        resourceRequestCpu: "100m"
                        resourceRequestMemory: "128Mi"
                        resourceLimitCpu: "500m"
                        resourceLimitMemory: "512Mi"

        credentials:
          system:
            domainCredentials:
              - credentials:
                  - usernamePassword:
                      id: "dockerhub-credentials"
                      username: "${DOCKERHUB_USERNAME}"
                      password: "${DOCKERHUB_TOKEN}"
                      description: "DockerHub Access Token for CI/CD"
                  - secretText:
                      id: "github-ci-token"
                      secret: "${GITHUB_TOKEN}"
                      description: "GitHub Token for Push from Jenkins"

  sidecars:
    configAutoReload:
      enabled: true

  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000

  podAnnotations: {}

  volumes:
    - name: docker-storage
      emptyDir: {}
    - name: docker-bin
      emptyDir: {}

  volumeMounts:
    - name: docker-bin
      mountPath: /usr/local/bin

agent:
  podName: "jenkins-agent"
  customJenkinsLabels:
    - jenkins-agent
  nodeUsageMode: NORMAL
  containers:
    - name: jnlp
      image: "jenkins/inbound-agent:alpine"
      ttyEnabled: true
  connectTimeout: 100
  runAsUser: 1000

persistence:
  enabled: true
  storageClass: local-path
  size: 8Gi

service:
  type: ClusterIP
  agentListenerPort: 50000