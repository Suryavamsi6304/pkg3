pipeline {
    agent any
    
    environment {
        PKG_NAME = "${env.JOB_NAME.split('-')[0]}"
    }
    
    stages {
        stage('Build') {
            steps {
                sh 'docker build -t ${PKG_NAME}:${BUILD_NUMBER} .'
            }
        }
        
        stage('Test') {
            steps {
                sh 'docker run --rm ${PKG_NAME}:${BUILD_NUMBER}'
            }
        }
        
        stage('Push') {
            when { branch 'main' }
            steps {
                sh 'docker tag ${PKG_NAME}:${BUILD_NUMBER} ${PKG_NAME}:latest'
            }
        }
    }
}