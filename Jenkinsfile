pipeline {
    agent any

    environment {
        // Docker Hub credentials (configure in Jenkins)
        DOCKER_HUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKER_IMAGE_NAME = 'yourusername/jenkins-demo-api'
        DOCKER_IMAGE_TAG = "${BUILD_NUMBER}"

        // Coverage threshold
        COVERAGE_THRESHOLD = '50'

        // Docker Hub push control
        DOCKER_HUB_AVAILABLE = 'true'
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
                sh 'echo "✅ Code checked out successfully"'
                sh 'ls -la'
            }
        }

        // ============================================
        // STAGE 2: Install Dependencies
        // ============================================
        stage('2️⃣ Install Dependencies') {
            steps {
                script {
                    echo '=========================================='
                    echo 'Stage 2: Installing Python dependencies...'
                    echo '=========================================='
                }
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                    echo "✅ Dependencies installed successfully"
                '''
            }
        }

        // ============================================
        // STAGE 3: Lint (Code Quality Check)
        // ============================================
        stage('3️⃣ Lint') {
            steps {
                script {
                    echo '=========================================='
                    echo 'Stage 3: Running Flake8 linting...'
                    echo '=========================================='
                }
                sh '''
                    . venv/bin/activate
                    echo "Running flake8 code quality checks..."
                    flake8 app/ tests/ --config=.flake8 || true
                    echo "✅ Linting completed"
                '''
            }
        }

        // ============================================
        // STAGE 4: Unit Tests
        // ============================================
        stage('4️⃣ Unit Tests') {
            steps {
                script {
                    echo '=========================================='
                    echo 'Stage 4: Running pytest with coverage...'
                    echo '=========================================='
                }
                sh '''
                    . venv/bin/activate
                    pytest tests/ \
                        --verbose \
                        --cov=app \
                        --cov-report=html:htmlcov \
                        --cov-report=xml:coverage.xml \
                        --cov-report=term-missing \
                        --junitxml=test-results.xml
                    echo "✅ Unit tests completed"
                '''
            }
        }

        // ============================================
        // STAGE 5: Coverage Check
        // ============================================
        stage('5️⃣ Coverage Check') {
            steps {
                script {
                    echo '=========================================='
                    echo "Stage 5: Checking coverage threshold (${COVERAGE_THRESHOLD}%)..."
                    echo '=========================================='
                }
                sh '''
                    . venv/bin/activate
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
                        echo "❌ Coverage ${coverage_percentage}% is below threshold ${COVERAGE_THRESHOLD}%"
                        exit 1
                    else
                        echo "✅ Coverage check passed!"
                    fi
                '''
            }
        }

        // ============================================
        // STAGE 6: Build Docker Image
        // ============================================
        stage('6️⃣ Build Docker Image') {
            steps {
                script {
                    echo '=========================================='
                    echo 'Stage 6: Building Docker image...'
                    echo '=========================================='
                }
                sh '''
                    echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                    docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} .
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest
                    echo "✅ Docker image built successfully"
                    docker images | grep ${DOCKER_IMAGE_NAME}
                '''
            }
        }

        // ============================================
        // STAGE 7: Push to Docker Hub (Optional)
        // ============================================
        stage('7️⃣ Push to Docker Hub') {
            when {
                // Only push on main/master branch or manual trigger
                allOf {
                    anyOf {
                        branch 'main'
                        branch 'master'
                        expression { params.FORCE_PUSH == true }
                    }
                    expression {
                        // Check if Docker Hub credentials are available
                        try {
                            withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USR', passwordVariable: 'DOCKER_PSW')]) {
                                return true
                            }
                        } catch (Exception e) {
                            echo "Docker Hub credentials not found, skipping push stage"
                            return false
                        }
                    }
                }
            }
            steps {
                script {
                    echo '=========================================='
                    echo 'Stage 7: Pushing image to Docker Hub...'
                    echo '=========================================='
                }
                sh '''
                    echo "Logging into Docker Hub..."
                    echo $DOCKER_HUB_CREDENTIALS_PSW | docker login -u $DOCKER_HUB_CREDENTIALS_USR --password-stdin

                    echo "Pushing image: ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                    docker push ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
                    docker push ${DOCKER_IMAGE_NAME}:latest

                    echo "✅ Docker image pushed successfully"
                    docker logout
                '''
            }
        }
    }

    // ============================================
    // POST-BUILD ACTIONS
    // ============================================
    post {
        always {
            echo '=========================================='
            echo 'Cleaning up and publishing reports...'
            echo '=========================================='

            // Publish test results
            node {
                junit testResults: 'test-results.xml', allowEmptyResults: true
            }

            // Publish coverage report
            node {
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'htmlcov',
                    reportFiles: 'index.html',
                    reportName: 'Coverage Report',
                    reportTitles: 'Code Coverage'
                ])

                // Archive artifacts
                archiveArtifacts artifacts: 'htmlcov/**, coverage.xml, test-results.xml',
                                 allowEmptyArchive: true
            }

            // Clean up Docker images to save space
            sh '''
                docker image prune -f || true
            '''
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
