#!groovy​
podTemplate(label: 'pod-hugo-app', containers: [
    containerTemplate(name: 'hugo', image: 'hugomods/hugo:latest', ttyEnabled: true, command: 'cat'),
    containerTemplate(name: 'helm', image: 'alpine/helm', ttyEnabled: true, command: 'cat',
        volumes: [secretVolume(secretName: 'kube-config', mountPath: '/root/.kube')]),
    containerTemplate(name: 'docker', image: 'docker', ttyEnabled: true, command: 'cat',
        envVars: [containerEnvVar(key: 'DOCKER_CONFIG', value: '/tmp/')],
        volumeMounts: [hostPathVolume(hostPath: '/tmp', mountPath: '/tmp', readOnly: false)])

                  
  ]) {

    node('pod-hugo-app') {

        def DOCKER_HUB_ACCOUNT = 'aksine'
        def DOCKER_IMAGE_NAME = 'hugo-app'
        def K8S_DEPLOYMENT_NAME = 'hugo-app'
         // Make the workspace writable

        stage('Clone Hugo App Repository') {
            checkout scm
 
            container('hugo') {
                stage('Build Hugo Site') {
                    sh ("mkdir -p ./cache")
                    sh ("hugo  -s ./hugo-app/  -d ../public/ --cacheDir=/home/jenkins/agent/workspace/Hugo/cache")
                }
            }
    

            container('docker') {
                stage('Docker Build & Push Current & Latest Versions') {
                    sh ("docker build -t ${DOCKER_HUB_ACCOUNT}/${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} .")
                    sh ("docker push ${DOCKER_HUB_ACCOUNT}/${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}")
                    sh ("docker tag ${DOCKER_HUB_ACCOUNT}/${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} ${DOCKER_HUB_ACCOUNT}/${DOCKER_IMAGE_NAME}:latest")
                    sh ("docker push ${DOCKER_HUB_ACCOUNT}/${DOCKER_IMAGE_NAME}:latest")
                }
            }

           container('helm') {
                stage('Deploy Helm Chart') {
                    sh ("helm install hugo bjw-s-charts/app-template -f helm.yaml --set image.tag=${env.BUILD_NUMBER} ")
                }
            }
        }
    }
}

