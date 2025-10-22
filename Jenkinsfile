pipeline {
    // EC2 kurulumumuz için 'agent any' olarak değiştirildi.
    agent any

    environment {
        COVERAGE_THRESHOLD = '50'
        DOCKER_IMAGE_NAME = 'yigittq/jenkins-demo-api' // Docker Hub kullanıcı adınız/repo adınız
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
                // DÜZELTME: '|| true' kaldırıldı. Lint hatası artık build'i durduracak.
                sh 'flake8 app/ tests/ --config=.flake8'
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
                    # Python imajında 'bc' yüklü gelmez, kuruyoruz.
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

        // DÜZELTİLMİŞ DEPLOY AŞAMASI (Hatalı yorum satırı kaldırıldı)
        stage('Deploy to Production EC2') {
            steps {
                script {
                    echo '🚀 Deploying application to Production EC2 (Sunucu B)...'
                    def imageTag = "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
                    def deployServerUser = 'ec2-user' // Sunucu B'nin kullanıcı adı
                    
                    // !!! DEĞİŞTİR !!! Buraya Sunucu B'nin (Deploy Sunucusu) Public IP adresini yazın
                    def deployServerIp = '54.87.26.234' 
                    
                    def appPort = '8001' // Sunucu B'nin Security Group'unda açtığımız port

                    withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sshagent(credentials: ['deploy-server-ssh-key']) {
                            
                            sh """
                                ssh -o StrictHostKeyChecking=no ${deployServerUser}@${deployServerIp} '
                                    
                                    echo "🎯 [Sunucu B] Başarıyla bağlandım!"
                                    
                                    echo "🔐 [Sunucu B] Docker Hub'a login oluyorum..."       
                                    echo "\${DOCKER_PASS}" | docker login -u "\${DOCKER_USER}" --password-stdin
                                    
                                    echo "🐳 [Sunucu B] Yeni imajı Docker Hub'dan çekiyorum: ${imageTag}"
                                    docker pull ${imageTag}
                                    
                                    echo "🛑 [Sunucu B] Eski konteyneri durduruyorum..."
                                    docker stop jenkins-demo-app || true
                                    docker rm jenkins-demo-app || true
                                    
                                    echo "🚀 [Sunucu B] Yeni konteyneri başlatıyorum..."
                                    docker run -d \\
                                        --name jenkins-demo-app \\
                                        -p ${appPort}:8000 \\
                                        ${imageTag}
                                    
                                    echo "🧹 [Sunucu B] Eski Docker imajlarını temizliyorum..."
                                    docker image prune -f

                                    echo "✅ [Sunucu B] Deployment tamamlandı!"
                                    echo "🌐 Uygulama artık burada çalışıyor: http://${deployServerIp}:${appPort}"
                                '
                            """
                        }
                    }
                }
            }
        }
    } // stages bloğu kapanışı

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