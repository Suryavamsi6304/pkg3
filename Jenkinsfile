// Copy this Jenkinsfile to each of your 15 GitHub repos

pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                script {
                    def packageName = env.JOB_NAME.split('-')[0]
                    docker.build("${packageName}:${BUILD_NUMBER}")
                }
            }
        }
        
        stage('Test') {
            steps {
                script {
                    def packageName = env.JOB_NAME.split('-')[0]
                    sh "docker run --rm ${packageName}:${BUILD_NUMBER}"
                }
            }
        }
        
        stage('Push') {
            when { branch 'main' }
            steps {
                script {
                    def packageName = env.JOB_NAME.split('-')[0]
                    docker.withRegistry('', 'docker-hub-credentials') {
                        docker.image("${packageName}:${BUILD_NUMBER}").push()
                        docker.image("${packageName}:${BUILD_NUMBER}").push('latest')
                    }
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}