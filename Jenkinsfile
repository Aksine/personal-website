#!groovy​
     podTemplate(label: 'pod-hugo-app', containers: [
                    containerTemplate(name: 'hugo', image: 'hugomods/hugo:latest', ttyEnabled: true, command: 'cat'),
                    containerTemplate(name: 'helm', image: 'alpine/helm', ttyEnabled: true, command: 'cat'),
                    containerTemplate(name: 'kaniko', image: 'gcr.io/kaniko-project/executor:debug', imagePullPolicy: 'Always', command: 'sleep', args: '9999999')

                ],
                volumes: [
                    hostPathVolume(hostPath: '/tmp', mountPath: '/tmp', readOnly: false),
                    hostPathVolume(hostPath: '/var/run/docker.sock', mountPath: '/var/run/docker.sock', readOnly: false),
                    secretVolume(secretName: 'kube-config', mountPath: '/root/.kube'),
                    secretVolume(secretName: 'docker-config', mountPath: '/kaniko/.docker')
                ]
                ) 
{

    node('pod-hugo-app') {

        def DOCKER_HUB_ACCOUNT = 'aksine'
        def DOCKER_IMAGE_NAME = 'hugo-app'
        def K8S_DEPLOYMENT_NAME = 'hugo-app'
        def DOCKER_BUILD_CONTEXT = '/home/jenkins/agent/workspace/Hugo' // Specify your desired build context directory
                    
         // Make the workspace writable

        stage('Clone Hugo App Repository') {
            checkout scm
 
            container('hugo') {
                stage('Build Hugo Site') {
                    sh ("mkdir -p ./cache")
                    sh ("hugo  -s ./hugo-app/  -d ../public/ --cacheDir=/home/jenkins/agent/workspace/Hugo/cache")
                }
            }
    

            container('kaniko') {
                stage('Docker Build & Push Current & Latest Versions') {
                    sh "/kaniko/executor -f `pwd`/Dockerfile -c `pwd` --cache=true --destination=${DOCKER_HUB_ACCOUNT}/${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}"
                }
            }

            container('helm') {
                stage('Check Helm Release') {
                    script {
                        def releaseExists = sh(script: "helm list -q | grep -q '^hugo$'", returnStatus: true)
                        sh ("helm repo add bjw-s-charts https://bjw-s.github.io/helm-charts/")
                        if (releaseExists == 0) {
                            // Helm release exists, perform an upgrade
          
                            sh "helm upgrade hugo bjw-s-charts/app-template -f Helm.yml --set-string controllers.main.containers.main.image.tag=${env.BUILD_NUMBER}"
                        } else {
                            // Helm release does not exist, perform an install
                        
                            sh "helm install hugo bjw-s-charts/app-template -f Helm.yml --set-string controllers.main.containers.main.image.tag=${env.BUILD_NUMBER}"
                        }
                        }
                    }
            }
        
    }
}

