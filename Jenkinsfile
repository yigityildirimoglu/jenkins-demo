pipeline {
  agent any

  parameters {
    string(name: 'ALB_LISTENER_ARN', defaultValue: 'arn:aws:elasticloadbalancing:us-east-1:339712914983:listener/app/myy-app-alb/37b5761ecd032b70/06ce330922577902', description: 'ALB Listener ARN')
    string(name: 'ALB_RULE_ARN',     defaultValue: 'arn:aws:elasticloadbalancing:us-east-1:339712914983:listener-rule/app/myy-app-alb/37b5761ecd032b70/06ce330922577902/1afe0a8efa857a88', description: 'ALB Rule ARN')
    string(name: 'BLUE_TG_ARN',      defaultValue: 'arn:aws:elasticloadbalancing:us-east-1:339712914983:targetgroup/blue-target-group/c30aa629d3539f3a', description: 'BLUE Target Group ARN')
    string(name: 'GREEN_TG_ARN',     defaultValue: 'arn:aws:elasticloadbalancing:us-east-1:339712914983:targetgroup/green-target-group/e2f25f519c58a5c1', description: 'GREEN Target Group ARN')
    string(name: 'BLUE_SERVER_IP',   defaultValue: '98.94.89.99', description: 'BLUE sunucu IP')
    string(name: 'GREEN_SERVER_IP',  defaultValue: '13.221.17.82', description: 'GREEN sunucu IP')
  }

  environment {
    COVERAGE_THRESHOLD = '50'
    DOCKER_IMAGE_NAME  = 'yigittq/jenkins-demo-api'
    DOCKER_TAG         = "${env.BUILD_NUMBER}"
    DOCKER_REGISTRY    = 'docker.io'
    PYTHON_AGENT_IMAGE = 'yigittq/my-python-agent:v1.0.0-uv'

    AWS_REGION       = 'us-east-1'
    ALB_LISTENER_ARN = "${params.ALB_LISTENER_ARN}"
    ALB_RULE_ARN     = "${params.ALB_RULE_ARN}"
    BLUE_TG_ARN      = "${params.BLUE_TG_ARN}"
    GREEN_TG_ARN     = "${params.GREEN_TG_ARN}"

    BLUE_SERVER_IP   = "${params.BLUE_SERVER_IP}"
    GREEN_SERVER_IP  = "${params.GREEN_SERVER_IP}"
  }

  options { timestamps() }

  stages {
    stage('Checkout') {
      // ... (Değişiklik yok) ...
      steps {
        echo '📥 Checking out code from Git...'
        checkout scm
      }
    }

    stage('Quality & Tests') {
      // ... (Değişiklik yok) ...
      agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
      steps {
        sh '''
          set -Eeuo pipefail
          echo "🧩 uv sync (frozen) running..."
          uv sync --frozen --all-extras
          echo "🔎 pip-audit (known vulns)..."
          uv run pip-audit --ignore-vuln GHSA-4xh5-x5gv-qwph
          echo "🧼 flake8 lint..."
          uv run flake8 app/ tests/ --config=.flake8
          echo "🧪 pytest with coverage..."
          uv run pytest tests/ --verbose \
              --cov=app \
              --cov-report=html:htmlcov \
              --cov-report=xml:coverage.xml \
              --cov-report=term-missing \
              --junitxml=test-results.xml
          echo "✅ Quality & Tests finished."
        '''
      }
    }

    stage('Coverage Check') {
      // ... (Değişiklik yok) ...
      agent { docker { image "${env.PYTHON_AGENT_IMAGE}"; args '-u root' } }
      steps {
        sh '''
          set -Eeuo pipefail
          echo "📊 Checking coverage threshold (${COVERAGE_THRESHOLD}%)..."
          uv run python - <<'PY'
import os, sys
import xml.etree.ElementTree as ET
thr = float(os.environ.get('COVERAGE_THRESHOLD', '50'))
root = ET.parse('coverage.xml').getroot()
pct = float(root.attrib.get('line-rate', '0')) * 100.0
print(f"Current coverage: {pct:.2f}%")
print(f"Required coverage: {thr}%")
sys.exit(0 if pct >= thr else 2)
PY
        '''
      }
    }

    stage('Build Docker Image') {
      // ... (Değişiklik yok) ...
      steps {
        script {
          echo '🐳 Building Docker image...'
          def imageTag    = "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
          def imageLatest = "${DOCKER_IMAGE_NAME}:latest"
          sh 'set -Eeuo pipefail'
          sh "docker build -t ${imageTag} -t ${imageLatest} ."
          echo "✅ Docker image built: ${imageTag}, ${imageLatest}"
        }
      }
    }

    stage('Push to Docker Hub') {
      // ... (Değişiklik yok) ...
      steps {
        script {
          echo '📤 Pushing Docker image to Docker Hub...'
          def imageTag    = "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
          def imageLatest = "${DOCKER_IMAGE_NAME}:latest"
          withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
            sh 'set -Eeuo pipefail'
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

            def currentTarget = sh(
              script: """
                aws elbv2 describe-rules \
                  --rule-arn ${ALB_RULE_ARN} \
                  --region ${AWS_REGION} \
                  --query "Rules[0].Actions[0].TargetGroupArn" \
                  --output text
              """,
              returnStdout: true
            ).trim()

            echo "DEBUG: Sorgulanan Aktif Target ARN: [${currentTarget}]"
            if (currentTarget == null || currentTarget.isEmpty() || currentTarget == "None") {
                error("❌ Aktif Target Group ARN alınamadı! AWS CLI sorgusu 'null' veya boş döndü.")
            }

            def isBlueActive = (currentTarget == BLUE_TG_ARN)
            def targetServer = isBlueActive ? GREEN_SERVER_IP : BLUE_SERVER_IP
            def targetTG     = isBlueActive ? GREEN_TG_ARN : BLUE_TG_ARN
            def targetEnv    = isBlueActive ? 'GREEN' : 'BLUE'

            echo "📍 Current active: ${isBlueActive ? 'BLUE' : 'GREEN'}"
            echo "🎯 Deploying to: ${targetEnv} (${targetServer})"

            
            // *** YENİ EKLENEN DEBUG BLOĞU ***
            echo "DEBUG: Hangi 'varsayılan' SSH anahtarının kullanıldığını logluyorum..."
            sh(
              script: """
                # -v: Verbose (ayrıntılı) modu açar, hangi anahtar dosyalarını denediğini gösterir
                # -o ConnectTimeout=5: Hızlıca bağlanmayı dener
                # "hostname": Sadece basit bir komut çalıştırır ve bağlantıyı kapatır
                ssh -v -o StrictHostKeyChecking=no -o ConnectTimeout=5 ec2-user@${targetServer} "hostname"
              """
            )
            echo "DEBUG: SSH loglama tamamlandı. Asıl deploy script'i başlıyor..."
            // *** DEBUG BLOĞU SONU ***

            
            // 🔧 Asıl SSH heredoc komutları (değişiklik yok)
            sh(
              script: """
ssh -o StrictHostKeyChecking=no ec2-user@${targetServer} <<'EOSSH'
set -Eeuo pipefail

echo "🧹 Cleaning up Docker on \$(hostname)..."
# 8001'i publish eden TÜM container'ları temizle (isimden bağımsız)
docker ps -q --filter "publish=8001" | xargs -r docker rm -f

# İdempotent: aynı isim varsa ayrıca temizle
docker rm -f myapp 2>/dev/null || true

# Nazik prune (cache'i tamamen öldürme)
docker image prune -f --filter "until=168h" || true
docker container prune -f || true

echo "📥 Pulling new image..."
docker pull ${DOCKER_IMAGE_NAME}:${DOCKER_TAG}

echo "🚀 Starting new container..."
docker run -d \\
  --name myapp \\
  -p 8001:8001 \\
  --restart unless-stopped \\
  ${DOCKER_IMAGE_NAME}:${DOCKER_TAG}

echo "✅ Post-run verify:"
docker ps --format 'table {{.ID}}\\t{{.Names}}\\t{{.Ports}}' | sed -n '1,8p'
EOSSH
              """.stripIndent()
            )

            echo '🏥 Running health checks...'
            // ... (Health check logic - değişiklik yok) ...
            def healthOk = false
            sleep 5
            for (int i = 0; i < 60; i++) {
              def status = sh(
                script: """
                  curl -s -o /dev/null -w '%{http_code}' \
                    --connect-timeout 2 --max-time 5 \
                    http://${targetServer}:8001/health || echo '000'
                """,
                returnStdout: true
              ).trim()
              echo "Health check response: ${status}"
              if (status == '200') { healthOk = true; break }
              sleep 2
            }
            if (!healthOk) { error("❌ Health check failed after 120 seconds!") }

            echo '🔄 Switching traffic to new environment...'
            // ... (modify-rule logic - değişiklik yok) ...
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
    // ... (Değişiklik yok) ...
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
      archiveArtifacts artifacts: 'test-results.xml, coverage.xml, htmlcov/**', fingerprint: true, allowEmptyArchive: true
    }
    success { echo '✅ Pipeline completed successfully!' }
    failure { echo '❌ Pipeline failed!' }
  }
}