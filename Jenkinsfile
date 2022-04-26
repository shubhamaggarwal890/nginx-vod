pipeline {
    agent any
    stages {
        stage('NFV module - SCM Checkout'){
            steps{
                git 'https://github.com/shubhamaggarwal890/nginx-vod.git'
            }
        }
        stage('Containerize NFV module'){
            steps{
                script {
                    dockerImage = docker.build dockerCalculator + ':latest'
                }
            }
        }
        stage('Push Docker Image over Docker registry'){
            steps{
                script {
                    docker.withRegistry('', 'docker-hub'){
                        dockerImage.push()
                    }
                }
            }
        }
    }
}
