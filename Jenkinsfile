pipeline {
    agent any

    environment {
        COVERAGE_THRESHOLD = '50'
        DOCKER_IMAGE_NAME = 'yigittq/jenkins-demo-api'
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        DOCKER_REGISTRY = 'docker.io'
        // *** DİKKAT: pyproject uyumlu YENİ agent imajınızın adını buraya yazın ***
        PYTHON_AGENT_IMAGE = 'yigittq/my-python-agent:v1.0.0-uv' // Yeni build ettiğiniz agent imajı etiketi

        // --- AWS Configuration ---
        AWS_REGION = 'us-east-1'
        ALB_LISTENER_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:listener/app/myy-app-alb/37b5761ecd032b70/06ce330922577902'
        ALB_RULE_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:listener-rule/app/myy-app-alb/37b5761ecd032b70/06ce330922577902/1afe0a8efa857a88'
        BLUE_TG_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:targetgroup/blue-target-group/c30aa629d3539f3a'
        GREEN_TG_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:targetgroup/green-target-group/e2f25f519c58a5c1'
        BLUE_SERVER_IP = '54.87.26.234'
        GREEN_SERVER_IP = '18.209.12.9'
    }

    stages {
        stage('Checkout') {
             steps {
                echo 'Checking out code from Git...'
                // Kodu (pyproject.toml ve uv.lock dahil) çeker
                checkout scm
            }
        }

        // *** UV SYNC ile GÜNCELLENDİ ***
        stage('Install Project Dependencies') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Installing project dependencies using uv sync...'
                // Kilit dosyasını (uv.lock) kullanarak SADECE ana bağımlılıkları kurar
                sh 'uv sync --system'
                sh 'echo "Project dependencies installed."'
            }
        }

        // *** UV SYNC ve Agent İmajı ile GÜNCELLENDİ ***
        stage('Vulnerability Check') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Checking for known vulnerabilities using pip-audit...'
                // pip-audit'in kurulu ortamı tarayabilmesi için bağımlılıklar kurulmalı
                // Sadece ana bağımlılıkları kurmak genellikle yeterlidir
                sh 'uv sync --system'
                // pip-audit komutunu çalıştır (agent imajında kurulu)
                sh 'pip-audit --ignore-vuln GHSA-4xh5-x5gv-qwph' // pip açığını yok saymaya devam
                echo '✅ Vulnerability check passed.'
            }
        }

        // *** Agent İmajı ile GÜNCELLENDİ (Değişiklik yoktu) ***
        stage('Lint') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Running code quality checks (flake8 is pre-installed)...'
                // Lint için bağımlılık kurulumu gerekmez
                sh 'flake8 app/ tests/ --config=.flake8'
            }
        }

        // *** UV SYNC --dev ile GÜNCELLENDİ ***
        stage('Unit Tests') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Running unit tests with coverage (pytest is pre-installed)...'
                echo 'Installing project dependencies (including dev) for tests using uv sync...'
                // Testlerin çalışması için hem ana hem de dev bağımlılıkları gerekli.
                // uv sync --dev: kilit dosyasındaki dev bağımlılıklarını da kurar.
                sh 'uv sync --dev --system'
                echo 'Executing pytest...'
                sh '''
                    pytest tests/ --verbose --cov=app --cov-report=html:htmlcov \
                        --cov-report=xml:coverage.xml --cov-report=term-missing \
                        --junitxml=test-results.xml
                '''
            }
        }

        // *** Agent İmajı ile GÜNCELLENDİ (Değişiklik yoktu) ***
        stage('Coverage Check') {
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo "Checking coverage threshold (${COVERAGE_THRESHOLD}%)..."
                // Bağımlılık kurulumuna gerek yok
                sh '''
                    coverage_percentage=$(python -c "
import xml.tree.ElementTree as ET
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

        // --- Build, Push, Deploy Aşamaları (Mantık Değişikliği Yok) ---
        // Not: 'Build Docker Image' aşaması, sizin güncellediğiniz (uv sync kullanan)
        // UYGULAMA Dockerfile'ını ('Dockerfile') kullanacaktır.
        stage('Build Docker Image') { /* ... önceki gibi ... */ }
        stage('Push to Docker Hub') { /* ... önceki gibi ... */ }
        stage('Deploy Blue/Green') { /* ... önceki gibi ... */ }
    } // stages bloğu kapanışı
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