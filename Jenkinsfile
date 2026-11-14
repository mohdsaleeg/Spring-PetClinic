pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Test') {
            steps {
                sh 'chmod +x mvnw'
                sh './mvnw -B clean package'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
             steps {
                withSonarQubeEnv('sonarqube') {
                    sh '''
                    ./mvnw -B \
                    org.sonarsource.scanner.maven:sonar-maven-plugin:5.1.0.4751:sonar \
                    -Dsonar.projectKey=spring-petclinic \
                    -Dsonar.host.url="$SONAR_HOST_URL" \
                    -Dsonar.token="$SONAR_AUTH_TOKEN"
                    '''
                }
            }
        }

        stage('SonarQube Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Dependency Scan (Trivy)') {
            steps {
                sh '''
                    trivy fs --scanners vuln \
                      --severity HIGH,CRITICAL \
                      --format table \
                      --output trivy-deps-report.txt \
                      --cache-dir /var/jenkins_home/.trivy-cache .

                    cat trivy-deps-report.txt

                    trivy fs --scanners vuln \
                      --severity CRITICAL \
                      --exit-code 1 \
                      --cache-dir /var/jenkins_home/.trivy-cache \
                      --quiet .
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-deps-report.txt',
                                     allowEmptyArchive: true
                }
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'target/*.jar',
                                 fingerprint: true
            }
        }
    }

    post {
        success {
            echo 'Build, tests, SonarQube and Trivy scan passed.'
        }

        failure {
            echo 'Pipeline failed. Check the Console Output.'
        }
    }
}