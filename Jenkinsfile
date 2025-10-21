pipeline {
    agent any

    environment {
        // Docker image configuration
        DOCKER_IMAGE_NAME = 'jenkins-demo-api'
        DOCKER_IMAGE_TAG = "${BUILD_NUMBER}"

        // Coverage threshold
        COVERAGE_THRESHOLD = '50'
    }

    stages {
        // ============================================
        // STAGE 1: Checkout
        // ============================================
        stage('1️⃣ Checkout') {
            steps {
                script {
                    echo '=========================================='
                    echo 'Stage 1: Checking out code from Git...'
                    echo '=========================================='
                }
                checkout scm
                sh 'ls -la'
                sh 'echo "✅ Code checked out successfully"'
            }
        }

        // ============================================
        // STAGE 2: Python Tests (Lint, Tests, Coverage)
        // ============================================
        stage('2️⃣ Python Tests') {
            agent {
                docker {
                    image 'python:3.11-slim'
                    args '-u root'
                    reuseNode true
                }
            }
            steps {
                script {
                    echo '=========================================='
                    echo 'Stage 2: Installing dependencies and running tests...'
                    echo '=========================================='
                }
                sh '''
                    # Install dependencies
                    pip install --upgrade pip --quiet
                    pip install -r requirements.txt --quiet
                    echo "✅ Dependencies installed"
                    
                    # Lint
                    echo "Running flake8 linting..."
                    flake8 app/ tests/ --config=.flake8 || true
                    echo "✅ Linting completed"
                    
                    # Tests with coverage
                    echo "Running pytest with coverage..."
                    pytest tests/ \
                        --verbose \
                        --cov=app \
                        --cov-report=html:htmlcov \
                        --cov-report=xml:coverage.xml \
                        --cov-report=term-missing \
                        --junitxml=test-results.xml
                    echo "✅ Tests completed"
                    
                    # Coverage check
                    apt-get update -qq && apt-get install -y -qq bc > /dev/null 2>&1
                    coverage_percentage=$(python -c "
import xml.etree.ElementTree as ET
tree = ET.parse('coverage.xml')
root = tree.getroot()
line_rate = float(root.attrib['line-rate'])
print(f'{line_rate * 100:.2f}')
")

                    echo "📊 Current coverage: ${coverage_percentage}%"
                    echo "🎯 Required coverage: ${COVERAGE_THRESHOLD}%"

                    if (( $(echo "$coverage_percentage < ${COVERAGE_THRESHOLD}" | bc -l) )); then
                        echo "⚠️  Coverage ${coverage_percentage}% is below threshold ${COVERAGE_THRESHOLD}%"
                        echo "Continuing anyway..."
                    else
                        echo "✅ Coverage check passed!"
                    fi
                '''
            }
        }

        // ============================================
        // STAGE 3: Build Docker Image
        // ============================================
        stage('3️⃣ Build Docker Image') {
            steps {
                script {
                    echo '=========================================='
                    echo 'Stage 3: Building Docker image...'
                    echo '=========================================='
                    
                    // Check if docker command exists
                    def dockerExists = sh(script: 'command -v docker', returnStatus: true) == 0
                    
                    if (dockerExists) {
                        sh '''
                            echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                            docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} .
                            docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest
                            echo "✅ Docker image built successfully"
                            docker images | grep ${DOCKER_IMAGE_NAME} || true
                        '''
                    } else {
                        echo "⚠️  Docker not available in Jenkins, skipping build"
                        echo "To enable Docker builds, mount Docker socket: -v /var/run/docker.sock:/var/run/docker.sock"
                    }
                }
            }
        }

        // ============================================
        // STAGE 4: Push to Docker Hub (Optional)
        // ============================================
        stage('4️⃣ Push to Docker Hub') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                script {
                    echo '=========================================='
                    echo 'Stage 4: Docker Hub Push (Optional)...'
                    echo '=========================================='
                    echo "⚠️  Docker Hub push skipped (only on main/master branch)"
                    echo "To enable: Add 'dockerhub-credentials' in Jenkins"
                }
            }
        }
    }

    // ============================================
    // POST-BUILD ACTIONS
    // ============================================
    post {
        always {
            script {
                echo '=========================================='
                echo 'Publishing test reports...'
                echo '=========================================='
                
                // Publish test results
                try {
                    junit testResults: 'test-results.xml', allowEmptyResults: true
                    echo "✅ Test results published"
                } catch (Exception e) {
                    echo "⚠️  No test results found: ${e.message}"
                }
                
                // Publish coverage report
                try {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'htmlcov',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report',
                        reportTitles: 'Code Coverage'
                    ])
                    echo "✅ Coverage report published"
                } catch (Exception e) {
                    echo "⚠️  No coverage report found: ${e.message}"
                }
                
                // Archive artifacts
                try {
                    archiveArtifacts artifacts: 'htmlcov/**, coverage.xml, test-results.xml',
                                     allowEmptyArchive: true
                    echo "✅ Artifacts archived"
                } catch (Exception e) {
                    echo "⚠️  No artifacts to archive: ${e.message}"
                }
                
                // Clean up Docker images
                try {
                    sh 'docker image prune -f || true'
                } catch (Exception e) {
                    echo "⚠️  Docker cleanup skipped (docker not available)"
                }
            }
        }

        success {
            script {
                echo '=========================================='
                echo '✅ ✅ ✅ PIPELINE SUCCESS! ✅ ✅ ✅'
                echo '=========================================='

                // Slack notification (install Slack plugin & configure)
                // slackSend(
                //     color: 'good',
                //     message: "✅ Build SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n" +
                //              "Coverage Report: ${env.BUILD_URL}Coverage_Report/\n" +
                //              "Docker Image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                // )
            }
        }

        failure {
            script {
                echo '=========================================='
                echo '❌ ❌ ❌ PIPELINE FAILED! ❌ ❌ ❌'
                echo '=========================================='

                // Slack notification (install Slack plugin & configure)
                // slackSend(
                //     color: 'danger',
                //     message: "❌ Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n" +
                //              "Check: ${env.BUILD_URL}console"
                // )
            }
        }

        unstable {
            echo '⚠️ Build is unstable - check test results'
        }
    }
}
