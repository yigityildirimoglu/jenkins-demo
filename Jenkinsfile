pipeline {
    agent any

    environment {
        COVERAGE_THRESHOLD = '50'
        DOCKER_IMAGE_NAME = 'yigittq/jenkins-demo-api'
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        DOCKER_REGISTRY = 'docker.io'
        PYTHON_AGENT_IMAGE = 'yigittq/my-python-agent:v1.0.0-uv' // Agent imajınız

        // --- AWS Configuration ---
        AWS_REGION = 'us-east-1'
        ALB_LISTENER_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:listener/app/myy-app-alb/37b5761ecd032b70/06ce330922577902'
        ALB_RULE_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:listener-rule/app/myy-app-alb/37b5761ecd032b70/06ce330922577902/1afe0a8efa857a88'
        BLUE_TG_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:targetgroup/blue-target-group/c30aa629d3539f3a'
        GREEN_TG_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:targetgroup/green-target-group/e2f25f519c58a5c1'

        // --- Server IPs ---
        BLUE_SERVER_IP = '54.87.26.234'
        GREEN_SERVER_IP = '18.209.12.9'
    }

    stages {
        stage('Checkout') {
             steps {
                echo 'Checking out code from Git...'
                checkout scm
            }
        }

        stage('Install Project Dependencies') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Installing project dependencies using uv sync...'
                // *** DÜZELTME: --system kaldırıldı ***
                sh 'uv sync'
                sh 'echo "Project dependencies installed."'
            }
        }

        stage('Vulnerability Check') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Checking for known vulnerabilities using pip-audit...'
                // *** DÜZELTME: --system kaldırıldı ***
                sh 'uv sync' // Bağımlılıkları kur
                sh 'pip-audit --ignore-vuln GHSA-4xh5-x5gv-qwph' // pip açığını yok say
                echo '✅ Vulnerability check passed.'
            }
        }

        stage('Lint') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Running code quality checks (flake8 is pre-installed)...'
                sh 'flake8 app/ tests/ --config=.flake8'
            }
        }

        stage('Unit Tests') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Running unit tests with coverage (pytest is pre-installed)...'
                echo 'Installing project dependencies (including dev) for tests using uv sync...'
                // *** DÜZELTME: --system kaldırıldı ***
                sh 'uv sync --dev' // dev bağımlılıklarını da kur
                echo 'Executing pytest...'
                sh '''
                    pytest tests/ --verbose --cov=app --cov-report=html:htmlcov \
                        --cov-report=xml:coverage.xml --cov-report=term-missing \
                        --junitxml=test-results.xml
                '''
            }
        }

        stage('Coverage Check') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo "Checking coverage threshold (${COVERAGE_THRESHOLD}%)..."
                sh '''
                    coverage_percentage=$(python -c "
import xml.etree.ElementTree as ET
tree = ET.parse('coverage.xml')
root = tree.getroot()
line_rate = float(root.attrib['line-rate'])
print(f'{line_rate * 100:.2f}')
")
                    echo "Current coverage: ${coverage_percentage}%"
                    echo "Required coverage: ${COVERAGE_THRESHOLD}%"
                    result=$(echo "$coverage_percentage >= ${COVERAGE_THRESHOLD}" | bc -l)
                    if [ "$result" -eq 1 ]; then
                        echo "✅ Coverage check passed!"
                    else
                        echo "❌ Coverage ${coverage_percentage}% is below threshold ${COVERAGE_THRESHOLD}%"
                        exit 1
                    fi
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                script { ->
                    echo '🐳 Building Docker image...'
                    def imageTag = "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
                    def imageLatest = "${DOCKER_IMAGE_NAME}:latest"
                    sh "docker build -t ${imageTag} -t ${imageLatest} ."
                    echo "✅ Docker image built: ${imageTag}, ${imageLatest}"
                }
            }
        }
        stage('Push to Docker Hub') {
            steps {
                script { ->
                    echo '📤 Pushing Docker image to Docker Hub...'
                    def imageTag = "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
                    def imageLatest = "${DOCKER_IMAGE_NAME}:latest"
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh """
                            echo "🔐 Logging in to Docker Hub..."
                            echo "${DOCKER_PASS}" | docker login -u ${DOCKER_USER} --password-stdin
                            echo "📤 Pushing ${imageTag}..."
                            docker push ${imageTag}
                            echo "📤 Pushing ${imageLatest}..."
                            docker push ${imageLatest}
                            echo "✅ Docker images pushed successfully!"
                        """
                    }
                }
            }
        }

        stage('Deploy Blue/Green') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-deploy-credentials']]) {
                    script { ->
                        // 1. Canlı vs Boşta ortamı belirle
                        echo "Determining current LIVE environment by querying ALB Rule..."
                        def liveTargetGroupArn = sh(
                            script: """
                                aws elbv2 describe-rules --rule-arn ${env.ALB_RULE_ARN} \\
                                    --query 'Rules[0].Actions[0].TargetGroupArn' --output text --region ${env.AWS_REGION}
                            """,
                            returnStdout: true
                        ).trim()

                        def deployTargetGroupArn
                        def deployServerIp
                        def deployTgFriendlyName
                        def liveServerIp

                        if (liveTargetGroupArn == env.BLUE_TG_ARN) {
                            echo "Blue environment (${env.BLUE_SERVER_IP}) is LIVE. Deploying to GREEN."
                            deployTargetGroupArn = env.GREEN_TG_ARN
                            deployServerIp = env.GREEN_SERVER_IP
                            deployTgFriendlyName = "GREEN"
                            liveServerIp = env.BLUE_SERVER_IP
                        } else if (liveTargetGroupArn == env.GREEN_TG_ARN) {
                            echo "Green environment (${env.GREEN_SERVER_IP}) is LIVE. Deploying to BLUE."
                            deployTargetGroupArn = env.BLUE_TG_ARN
                            deployServerIp = env.BLUE_SERVER_IP
                            deployTgFriendlyName = "BLUE"
                            liveServerIp = env.GREEN_SERVER_IP
                        } else {
                            error "ALB Rule is pointing to an unknown Target Group ARN: ${liveTargetGroupArn}"
                        }

                        // 2. Boştaki sunucuya deploy et
                        echo "Deploying image ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_TAG} to IDLE [${deployTgFriendlyName}] server: ${deployServerIp}"
                        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                            sshagent(credentials: ['deploy-server-ssh-key']) {
                                sh """
                                    ssh -o StrictHostKeyChecking=no ec2-user@${deployServerIp} '
                                        echo "🎯 [${deployServerIp}] Connected!"
                                        echo "🔐 [${deployServerIp}] Logging in to Docker Hub..."
                                        echo "\${DOCKER_PASS}" | docker login -u "\${DOCKER_USER}" --password-stdin

                                        echo "🐳 [${deployServerIp}] Pulling image: ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_TAG}"
                                        docker pull ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_TAG}

                                        echo "🛑 [${deployServerIp}] Stopping old container..."
                                        docker stop jenkins-demo-app || true
                                        docker rm jenkins-demo-app || true

                                        echo "🚀 [${deployServerIp}] Starting new container on port 8001..."
                                        docker run -d --name jenkins-demo-app -p 8001:8000 --restart unless-stopped ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_TAG}

                                        echo "🧹 [${deployServerIp}] Pruning old images..."
                                        docker image prune -f

                                        echo "✅ [${deployServerIp}] Deployment script finished."
                                    '
                                """
                            }
                        }

                        // 3. Boştaki sunucuda sağlık kontrolü
                        echo "Waiting for application to start on [${deployTgFriendlyName}] server (${deployServerIp}) before health check..."
                        sleep(15) // Konteynerin başlaması için bekle

                        echo "Performing health check on [${deployTgFriendlyName}] server: http://${deployServerIp}:8001/health"
                        try {
                            sh "curl -fsS http://${deployServerIp}:8001/health"
                            echo "✅ [${deployTgFriendlyName}] Health check PASSED."
                        } catch (ex) {
                            echo "❌ [${deployTgFriendlyName}] Health check FAILED! See details below:"
                            echo ex.getMessage()
                            error "Deployment failed health check. Traffic switch aborted."
                        }

                        // 4. Trafiği ALB üzerinden çevir
                        echo "Health check passed. Flipping ALB traffic to target group [${deployTgFriendlyName}] (${deployTargetGroupArn})..."
                        sh """
                            aws elbv2 modify-rule --rule-arn ${env.ALB_RULE_ARN} \\
                                --actions Type=forward,TargetGroupArn=${deployTargetGroupArn} \\
                                --region ${env.AWS_REGION}
                        """

                        echo "✅ SUCCESS! Traffic is now flowing to [${deployTgFriendlyName}]."
                        echo "Old environment (Server IP: ${liveServerIp}) is now idle."
                    } // script kapanışı
                } // withCredentials [AWS] kapanışı
            } // steps kapanışı
        } // stage Deploy Blue/Green kapanışı
    } // stages bloğu kapanışı

    // --- Post Actions (Değişiklik Yok) ---
    post {
        always {
             junit testResults: 'test-results.xml', allowEmptyResults: true
             publishHTML(
                allowMissing: true, alwaysLinkToLastBuild: true, keepAll: true,
                reportDir: 'htmlcov', reportFiles: 'index.html', reportName: 'Coverage Report'
             )
        }
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
    }
}