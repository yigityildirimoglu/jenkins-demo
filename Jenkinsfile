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
        BLUE_SERVER_IP = '98.94.89.99' // Updated IP
        GREEN_SERVER_IP = '13.221.17.82' // Updated IP
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
                 // Using --frozen ensures it uses the lock file strictly
                sh 'uv sync --frozen'
                echo '✅ Project dependencies installed.'
            }
        }

        stage('Vulnerability Check') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Checking for known vulnerabilities using pip-audit...'
                // Sync dependencies again just in case, could potentially be removed if previous stage always runs
                sh 'uv sync --frozen'
                // Run pip-audit within the uv managed environment if needed, or directly if installed globally in agent
                // Assuming pip-audit is in the agent image's PATH now
                sh 'pip-audit --ignore-vuln GHSA-4xh5-x5gv-qwph'
                echo '✅ Vulnerability check passed.'
            }
        }

        stage('Lint') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Running code quality checks with flake8...'
                 // Sync dependencies might be needed if linters require them
                sh 'uv sync --frozen'
                // Run flake8 within the uv managed environment or directly if installed globally
                sh 'flake8 app/ tests/ --config=.flake8' // Assuming flake8 is in agent PATH
                echo '✅ Linting passed.'
            }
        }

        stage('Unit Tests') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Running unit tests with coverage...'
                // Sync dev dependencies for tests
                sh 'uv sync --frozen --all-extras' // Includes dev dependencies
                echo 'Executing pytest...'
                sh '''
                    pytest tests/ --verbose \
                        --cov=app \
                        --cov-report=html:htmlcov \
                        --cov-report=xml:coverage.xml \
                        --cov-report=term-missing \
                        --junitxml=test-results.xml
                ''' // Assuming pytest is in agent PATH or installed via sync --all-extras
                echo '✅ Tests completed.'
            }
        }

        stage('Coverage Check') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo "Checking coverage threshold (${COVERAGE_THRESHOLD}%)..."
                // This stage relies on the XML created in the previous stage and 'bc' from the agent image
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
                script { -> // Added missing arrow
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
                script { -> // Added missing arrow
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
                    script { -> // Added missing arrow
                        echo '🚀 Starting Blue/Green Deployment...'

                        // 1. Determine current live environment
                        def currentTarget = sh(
                            script: """
                                aws elbv2 describe-rules \\
                                    --rule-arn ${env.ALB_RULE_ARN} \\
                                    --region ${env.AWS_REGION} \\
                                    --query "Rules[0].Actions[0].TargetGroupArn" \\
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()

                        def isBlueActive = currentTarget == env.BLUE_TG_ARN
                        def targetServerIp = isBlueActive ? env.GREEN_SERVER_IP : env.BLUE_SERVER_IP
                        def targetTGArn = isBlueActive ? env.GREEN_TG_ARN : env.BLUE_TG_ARN
                        def targetEnvName = isBlueActive ? 'GREEN' : 'BLUE'
                        def liveServerIp = isBlueActive ? env.BLUE_SERVER_IP : env.GREEN_SERVER_IP // For logging

                        echo "📍 Current active environment: ${isBlueActive ? 'BLUE' : 'GREEN'}"
                        echo "🎯 Deploying image ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_TAG} to target environment: ${targetEnvName} (${targetServerIp})"

                        // 2. Deploy to the target (idle) server via SSH
                        // Use withCredentials for Docker Hub login on remote server
                        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                            sshagent(credentials: ['deploy-server-ssh-key']) {
                                sh """
                                    ssh -o StrictHostKeyChecking=no ec2-user@${targetServerIp} '
                                        echo "🎯 [${targetServerIp}] Connected."
                                        echo "🔐 [${targetServerIp}] Logging in to Docker Hub..."
                                        echo "\${DOCKER_PASS}" | docker login -u "\${DOCKER_USER}" --password-stdin

                                        echo "🐳 [${targetServerIp}] Pulling image ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_TAG}..."
                                        docker pull ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_TAG}

                                        echo "🛑 [${targetServerIp}] Stopping and removing old container 'myapp'..."
                                        docker stop myapp || true
                                        docker rm myapp || true

                                        echo "🚀 [${targetServerIp}] Starting new container 'myapp'..."
                                        # *** PORT MAPPING CORRECTED: Host 8001 -> Container 8000 ***
                                        docker run -d --name myapp -p 8001:8000 --restart unless-stopped ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_TAG}

                                        echo "🧹 [${targetServerIp}] Pruning old docker images..."
                                        docker image prune -f

                                        echo "✅ [${targetServerIp}] Deployment script finished."
                                    '
                                """
                            }
                        }

                        // 3. Health check the newly deployed server
                        echo "🏥 Waiting for application to start on [${targetEnvName}] server (${targetServerIp}) before health check..."
                        sleep(15) // Wait for container start

                        echo "Performing health check via curl on http://${targetServerIp}:8001/health..."
                        def healthOk = false
                        // Retry loop for health check
                        for (int i = 0; i < 30; i++) { // Retry up to 30 times (60 seconds)
                            try {
                                // *** HEALTH CHECK PORT CORRECTED: Check port 8001 ***
                                def healthStatus = sh(
                                    script: "curl -fsS -o /dev/null -w '%{http_code}' http://${targetServerIp}:8001/health || echo '000'",
                                    returnStdout: true
                                ).trim()

                                if (healthStatus == '200') {
                                    echo "✅ Health check PASSED on attempt ${i + 1}."
                                    healthOk = true
                                    break // Exit loop if successful
                                } else {
                                     echo "⏳ Health check attempt ${i + 1}/30 failed with status ${healthStatus}. Retrying in 2 seconds..."
                                }
                            } catch (Exception e) {
                                echo "⚠️ Health check attempt ${i + 1}/30 threw exception: ${e.message}. Retrying in 2 seconds..."
                            }
                            sleep 2 // Wait before retrying
                        }

                        // If health check failed after retries, abort the pipeline
                        if (!healthOk) {
                            error("❌ Health check FAILED after multiple attempts on [${targetEnvName}] server (${targetServerIp}). Aborting traffic switch.")
                        }

                        // 4. Switch ALB traffic
                        echo "🔄 Health check passed. Switching ALB traffic to target group [${targetEnvName}] (${targetTGArn})..."
                        sh """
                            aws elbv2 modify-rule \\
                                --rule-arn ${env.ALB_RULE_ARN} \\
                                --actions Type=forward,TargetGroupArn=${targetTGArn} \\
                                --region ${env.AWS_REGION}
                        """

                        echo "✅ SUCCESS! Traffic is now flowing to [${targetEnvName}]."
                        echo "Old environment (Server IP: ${liveServerIp}) is now idle."
                        echo "🎉 Blue/Green deployment completed successfully!"

                    } // script block ends
                } // withCredentials [AWS] ends
            } // steps block ends
        } // stage Deploy Blue/Green ends
    } // stages block ends

    // --- Post Actions (No Changes) ---
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