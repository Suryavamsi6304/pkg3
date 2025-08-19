stage('Rollback Deploy') {
    steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'suryavamsi6304', passwordVariable: 'Qwertz@2305')]) {
            sh '''
                echo "Rolling back to pkg${TARGET_PKG}..."

                # Stop and remove current container if exists
                docker stop current-deployment || true
                docker rm current-deployment || true

                # Login to Docker registry
                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                # Pull and run image from registry
                docker pull my-dockerhub-org/pkg${TARGET_PKG}-complete:${BUILD_NUMBER}
                docker run -d --name current-deployment -p 9000:80 my-dockerhub-org/pkg${TARGET_PKG}-complete:${BUILD_NUMBER}
            '''
        }
    }
}
