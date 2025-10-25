pipeline {
    agent any

    environment {
        COVERAGE_THRESHOLD = '50'
        DOCKER_IMAGE_NAME = 'yigittq/jenkins-demo-api'
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        DOCKER_REGISTRY = 'docker.io'
        PYTHON_AGENT_IMAGE = 'yigittq/my-python-agent:v1.0.0-uv'

        // --- AWS Configuration ---
        AWS_REGION = 'us-east-1'
        ALB_LISTENER_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:listener/app/myy-app-alb/37b5761ecd032b70/06ce330922577902'
        ALB_RULE_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:listener-rule/app/myy-app-alb/37b5761ecd032b70/06ce330922577902/1afe0a8efa857a88'
        BLUE_TG_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:targetgroup/blue-target-group/c30aa629d3539f3a'
        GREEN_TG_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:targetgroup/green-target-group/e2f25f519c58a5c1'

        // --- Server IPs ---
        BLUE_SERVER_IP = '98.94.89.99'
        GREEN_SERVER_IP = '13.221.17.82'  // Log'dan gördüğüm IP
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
                sh 'uv sync --frozen'
                echo '✅ Project dependencies installed.'
            }
        }

        stage('Vulnerability Check') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Checking for known vulnerabilities using pip-audit...'
                sh 'uv sync --frozen'
                sh 'uv run pip-audit --ignore-vuln GHSA-4xh5-x5gv-qwph'
                echo '✅ Vulnerability check passed.'
            }
        }

        stage('Lint') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Running code quality checks with flake8...'
                sh 'uv sync --frozen'
                sh 'uv run flake8 app/ tests/ --config=.flake8'
                echo '✅ Linting passed.'
            }
        }

        stage('Unit Tests') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Running unit tests with coverage...'
                sh 'uv sync --frozen --all-extras'
                sh '''
                    uv run pytest tests/ --verbose \
                        --cov=app \
                        --cov-report=html:htmlcov \
                        --cov-report=xml:coverage.xml \
                        --cov-report=term-missing \
                        --junitxml=test-results.xml
                '''
                echo '✅ Tests completed.'
            }
        }

        stage('Coverage Check') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo "Checking coverage threshold (${COVERAGE_THRESHOLD}%)..."
                sh '''
                    coverage_percentage=$(uv run python -c "
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
                script {
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
                script {
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
                    script {
                        echo '🚀 Starting Blue/Green Deployment...'
                        
                        // 1. Canlı ortamı belirle
                        def currentTarget = sh(
                            script: """
                                aws elbv2 describe-rules \
                                    --listener-arn ${ALB_LISTENER_ARN} \
                                    --region ${AWS_REGION} \
                                    --query "Rules[?RuleArn=='${ALB_RULE_ARN}'].Actions[0].TargetGroupArn" \
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()
                        
                        def isBlueActive = currentTarget == BLUE_TG_ARN
                        def targetServer = isBlueActive ? GREEN_SERVER_IP : BLUE_SERVER_IP
                        def targetTG = isBlueActive ? GREEN_TG_ARN : BLUE_TG_ARN
                        def targetEnv = isBlueActive ? 'GREEN' : 'BLUE'
                        
                        echo "📍 Current active: ${isBlueActive ? 'BLUE' : 'GREEN'}"
                        echo "🎯 Deploying to: ${targetEnv} (${targetServer})"
                        
                        // 2. Deploy yap
                        echo "🔄 Stopping old container on ${targetEnv}..."
                        sh """
                            ssh -o StrictHostKeyChecking=no ec2-user@${targetServer} '
                                # Eski container'ı durdur ve sil
                                docker stop myapp 2>/dev/null || true
                                docker rm myapp 2>/dev/null || true
                                
                                # Yeni image'i çek
                                docker pull ${DOCKER_IMAGE_NAME}:${DOCKER_TAG}
                                
                                # Yeni container'ı başlat (8001:8001 mapping)
                                docker run -d \
                                    --name myapp \
                                    -p 8001:8001 \
                                    --restart unless-stopped \
                                    ${DOCKER_IMAGE_NAME}:${DOCKER_TAG}
                                
                                # Container başladı mı kontrol et
                                sleep 2
                                docker ps | grep myapp
                            '
                        """
                        
                        // 3. Health check
                        echo '🏥 Running health checks...'
                        def healthOk = false
                        
                        // İlk önce container'ın ayağa kalkmasını bekle
                        echo "⏳ Waiting for container to start..."
                        sleep 5
                        
                        for (int i = 0; i < 30; i++) {
                            try {
                                def healthStatus = sh(
                                    script: """
                                        curl -s -o /dev/null -w '%{http_code}' \
                                            --connect-timeout 2 \
                                            --max-time 5 \
                                            http://${targetServer}:8001/health || echo '000'
                                    """,
                                    returnStdout: true
                                ).trim()
                                
                                echo "Health check response: ${healthStatus}"
                                
                                if (healthStatus == '200') {
                                    echo "✅ Health check passed!"
                                    healthOk = true
                                    break
                                }
                                echo "⏳ Waiting for service... (${i+1}/30) - Status: ${healthStatus}"
                                sleep 2
                            } catch (Exception e) {
                                echo "⚠️  Health check attempt ${i+1} failed: ${e.message}"
                                sleep 2
                            }
                        }
                        
                        if (!healthOk) {
                            error("❌ Health check failed after 60 seconds!")
                        }
                        
                        // 4. Traffic switch
                        echo '🔄 Switching traffic to new environment...'
                        sh """
                            aws elbv2 modify-rule \
                                --rule-arn ${ALB_RULE_ARN} \
                                --actions Type=forward,TargetGroupArn=${targetTG} \
                                --region ${AWS_REGION}
                        """
                        
                        echo "✅ Traffic switched to ${targetEnv}!"
                        echo "🎉 Blue/Green deployment completed successfully!"
                    }
                }
            }
        }
    }

    post {
        always {
            junit testResults: 'test-results.xml', allowEmptyResults: true
            publishHTML(
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'htmlcov',
                reportFiles: 'index.html',
                reportName: 'Coverage Report'
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