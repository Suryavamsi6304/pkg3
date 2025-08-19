stage('Rollback Deploy') {
    steps {
        sh '''
            echo "Rolling back to pkg${TARGET_PKG}..."

            # Stop & clean up existing container
            docker stop current-deployment || true
            docker rm current-deployment || true

            # Build image from Dockerfile in this repo
            docker build -t pkg${TARGET_PKG}-complete:${BUILD_NUMBER} .

            # Run container
            docker run -d --name current-deployment -p 9000:80 pkg${TARGET_PKG}-complete:${BUILD_NUMBER}
        '''
    }
}
