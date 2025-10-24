pipeline {
    agent any

    environment {
        COVERAGE_THRESHOLD = '50'
        DOCKER_IMAGE_NAME = 'yigittq/jenkins-demo-api' // Docker Hub kullanıcı adınız/repo adınız
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        DOCKER_REGISTRY = 'docker.io'
        // *** DİKKAT: UV içeren YENİ agent imajınızın adını buraya yazın ***
        PYTHON_AGENT_IMAGE = 'yigittq/my-python-agent:latest-uv' // Yeni etiketli imaj adı

        // --- AWS Configuration ---
        AWS_REGION = 'us-east-1' // AWS Bölgeniz
        ALB_LISTENER_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:listener/app/myy-app-alb/37b5761ecd032b70/06ce330922577902' // Listener ARN'niz
        ALB_RULE_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:listener-rule/app/myy-app-alb/37b5761ecd032b70/06ce330922577902/1afe0a8efa857a88' // Rule ARN'niz (Priority 1 olan)
        BLUE_TG_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:targetgroup/blue-target-group/c30aa629d3539f3a' // Blue Target Group ARN'niz
        GREEN_TG_ARN = 'arn:aws:elasticloadbalancing:us-east-1:339712914983:targetgroup/green-target-group/e2f25f519c58a5c1' // Green Target Group ARN'niz

        // --- Server IPs ---
        BLUE_SERVER_IP = '34.230.85.148'  // Sunucu B (Blue) Public IP Adresi
        GREEN_SERVER_IP = '98.81.246.237' // Sunucu C (Green) Public IP Adresi
    }

    stages {
        stage('Checkout') {
             steps {
                echo 'Checking out code from Git...'
                checkout scm
            }
        }

        // *** UV ile GÜNCELLENDİ ***
        stage('Install Project Dependencies') {
            // Yeni uv içeren agent imajı kullanılıyor
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Installing ONLY project Python dependencies using uv...'
                // pip yerine uv pip kullanılıyor
                sh 'uv pip install --quiet --system -r requirements.txt'
                sh 'echo "Project dependencies installed."'
            }
        }

        // *** UV ile GÜNCELLENDİ ***
        stage('Vulnerability Check') {
            // Yeni uv içeren agent imajı kullanılıyor
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Checking for known vulnerabilities using uv...'
                // Bağımlılıkları uv ile kur (audit için gerekli)
                sh 'uv pip install --quiet --system -r requirements.txt'
                // pip-audit yerine uv pip audit kullanılıyor
                sh 'uv pip audit'
                echo '✅ Vulnerability check passed.'
            }
        }

        // *** UV ile GÜNCELLENDİ (Sadece Agent) ***
        stage('Lint') {
            // Yeni uv içeren agent imajı kullanılıyor (içinde flake8 var)
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Running code quality checks (flake8 is pre-installed)...'
                // Kurulum komutu yok, flake8 zaten var
                sh 'flake8 app/ tests/ --config=.flake8'
            }
        }

        // *** UV ile GÜNCELLENDİ ***
        stage('Unit Tests') {
            // Yeni uv içeren agent imajı kullanılıyor (içinde pytest var)
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo 'Running unit tests with coverage (pytest is pre-installed)...'
                echo 'Installing project dependencies for tests using uv...'
                // Testler için bağımlılıklar uv ile kuruluyor
                sh 'uv pip install --quiet --system -r requirements.txt'
                echo 'Executing pytest...'
                // pytest zaten var
                sh '''
                    pytest tests/ --verbose --cov=app --cov-report=html:htmlcov \
                        --cov-report=xml:coverage.xml --cov-report=term-missing \
                        --junitxml=test-results.xml
                '''
            }
        }

        // *** UV ile GÜNCELLENDİ (Sadece Agent) ***
        stage('Coverage Check') {
            // Yeni uv içeren agent imajı kullanılıyor (içinde bc ve python var)
            agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
            steps {
                echo "Checking coverage threshold (${COVERAGE_THRESHOLD}%)..."
                // Kurulum komutu yok, bc zaten var
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

        // --- Build, Push, Deploy Aşamaları (Mantık Değişikliği Yok) ---
        // Not: 'Build Docker Image' aşaması, sizin güncellediğiniz (uv kullanan)
        // UYGULAMA Dockerfile'ını ('Dockerfile') kullanacaktır.
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
                        // 1. Canlı vs Boşta ortamı belirle (Değişiklik yok)
                        // ... ( önceki kod gibi ) ...
                        // 2. Boştaki sunucuya deploy et (Değişiklik yok)
                        // ... ( önceki kod gibi ) ...
                        // 3. Boştaki sunucuda sağlık kontrolü (Değişiklik yok)
                        // ... ( önceki kod gibi ) ...
                        // 4. Trafiği ALB üzerinden çevir (Değişiklik yok)
                        // ... ( önceki kod gibi ) ...
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