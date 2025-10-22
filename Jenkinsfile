pipeline {
    agent {
        docker {
            image 'docker:dind'
            args '-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    environment {
        COVERAGE_THRESHOLD = '50'
        DOCKER_IMAGE_NAME = 'yigittq/jenkins-demo-api'
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        DOCKER_REGISTRY = 'docker.io'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from Git...'
                checkout scm
            }
        }

        stage('Install Dependencies') {
            agent {
                docker {
                    image 'python:3.11'
                    args '-u root'
                }
            }
            steps {
                echo 'Installing Python dependencies...'
                sh 'pip install --quiet --upgrade pip'
                sh 'pip install --quiet -r requirements.txt'
                sh 'echo "Dependencies installed successfully"'
            }
        }

        stage('Lint') {
            agent {
                docker {
                    image 'python:3.11'
                    args '-u root'
                }
            }
            steps {
                echo 'Installing Python dependencies...'
                sh 'pip install --quiet --upgrade pip'
                sh 'pip install --quiet -r requirements.txt'

                echo 'Running code quality checks...'
                sh 'flake8 app/ tests/ --config=.flake8 || true'
                sh 'echo "Linting completed"'
            }
        }

        stage('Unit Tests') {
            agent {
                docker {
                    image 'python:3.11'
                    args '-u root'
                }
            }
            steps {
                echo 'Installing Python dependencies...'
                sh 'pip install --quiet --upgrade pip'
                sh 'pip install --quiet -r requirements.txt'

                echo 'Running unit tests with coverage...'
                sh '''
                    pytest tests/ \
                        --verbose \
                        --cov=app \
                        --cov-report=html:htmlcov \
                        --cov-report=xml:coverage.xml \
                        --cov-report=term-missing \
                        --junitxml=test-results.xml
                '''
                sh 'echo "Tests completed"'
            }
        }

        stage('Coverage Check') {
            agent {
                docker {
                    image 'python:3.11'
                    args '-u root'
                }
            }
            steps {
                echo 'Installing Python dependencies...'
                sh 'pip install --quiet --upgrade pip'
                sh 'pip install --quiet -r requirements.txt'

                echo "Checking coverage threshold (${COVERAGE_THRESHOLD}%)..."
                sh '''
                    apt-get update -qq && apt-get install -y -qq bc > /dev/null 2>&1

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
                script {
                    echo '🐳 Building Docker image...'
                    echo "📊 Build Number: ${env.BUILD_NUMBER}"
                    echo "🔢 Job Name: ${env.JOB_NAME}"
                    echo "🔗 Build URL: ${env.BUILD_URL}"

                    def imageTag = "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
                    def imageLatest = "${DOCKER_IMAGE_NAME}:latest"

                    sh """
                        docker build -t ${imageTag} -t ${imageLatest} .
                        echo "✅ Docker image built successfully!"
                        echo "   - ${imageTag}"
                        echo "   - ${imageLatest}"
                    """
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    echo '📤 Pushing Docker image to Docker Hub...'
                    echo "📦 Repository: ${DOCKER_IMAGE_NAME}"
                    echo "🏷️  Tag: ${DOCKER_TAG}"

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
                            echo "   - ${imageTag}"
                            echo "   - ${imageLatest}"
                        """
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    echo '🚀 Deploying application...'
                    def imageTag = "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
                    def imageLatest = "${DOCKER_IMAGE_NAME}:latest"

                    sh """
                        echo "Stopping existing container if running..."
                        docker stop jenkins-demo-app || true
                        docker rm jenkins-demo-app || true

                        echo "Starting new container with image: ${imageTag}"
                        docker run -d \\
                            --name jenkins-demo-app \\
                            -p 8001:8000 \\
                            ${imageTag}

                        echo "⏳ Waiting for application to start..."
                        sleep 10

                        echo "🔍 Checking if app is running..."
                        docker ps | grep jenkins-demo-app

                        echo "✅ Deployment completed!"
                        echo "🌐 App available at: http://localhost:8001"
                        echo "💚 Health check: http://localhost:8001/health"
                        echo "📦 Image: ${imageTag}"
                    """
                }
            }
        }
    }

    post {
        always {
            junit testResults: 'test-results.xml', allowEmptyResults: true
            publishHTML([
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'htmlcov',
                reportFiles: 'index.html',
                reportName: 'Coverage Report'
            ])
        }
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
    }
}
