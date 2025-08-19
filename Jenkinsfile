pipeline {
    agent any
    
    parameters {
        choice(name: 'TARGET_PKG', choices: ['1','2','3','4','5','6','7','8','9','10','11','12','13','14','15'], description: 'Package to rollback to')
        string(name: 'BUILD_NUMBER', defaultValue: 'latest', description: 'Build number to rollback to')
    }
    
    stages {
        stage('Rollback Deploy') {
            steps {
                sh '''
                    echo "Rolling back to pkg${TARGET_PKG}..."
                    
                    # Stop current deployment
                    docker stop current-deployment || true
                    docker rm current-deployment || true
                    
                    # Deploy target package
                    docker run -d --name current-deployment -p 9000:80 pkg${TARGET_PKG}-complete:${BUILD_NUMBER}
                    
                    echo "Rollback to pkg${TARGET_PKG} completed!"
                '''
            }
        }
        
        stage('Verify Rollback') {
            steps {
                sh '''
                    sleep 5
                    echo "Verifying rollback..."
                    docker ps | grep current-deployment
                    echo "Rollback verification completed"
                '''
            }
        }
    }
}