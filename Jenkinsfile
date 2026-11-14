pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
  }

  triggers {
    pollSCM('H/2 * * * *')   // check GitHub about every 2 minutes
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build & Test') {
      steps {
        sh 'chmod +x mvnw'
        sh './mvnw -B clean package'
      }
      post {
        always { junit 'target/surefire-reports/*.xml' }
      }
    }

    stage('Archive') {
      steps { archiveArtifacts artifacts: 'target/*.jar', fingerprint: true }
    }
  }

  post {
    success { echo 'Build and tests passed.' }
    failure { echo 'Build failed. Check the console output.' }
  }
}