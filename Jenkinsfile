pipeline {
    agent {
        docker {
            image 'python:3.11-slim'
            args '-u root'
        }
    }

    environment {
        COVERAGE_THRESHOLD = '50'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from Git...'
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                echo 'Installing Python dependencies...'
                sh 'pip install --quiet --upgrade pip'
                sh 'pip install --quiet -r requirements.txt'
                sh 'echo "Dependencies installed successfully"'
            }
        }

        stage('Lint') {
            steps {
                echo 'Running code quality checks...'
                sh 'flake8 app/ tests/ --config=.flake8 || true'
                sh 'echo "Linting completed"'
            }
        }

        stage('Unit Tests') {
            steps {
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
            steps {
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
                    
                    if (( $(echo "$coverage_percentage >= ${COVERAGE_THRESHOLD}" | bc -l) )); then
                        echo "✅ Coverage check passed!"
                    else
                        echo "❌ Coverage ${coverage_percentage}% is below threshold ${COVERAGE_THRESHOLD}%"
                        exit 1
                    fi
                '''
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
