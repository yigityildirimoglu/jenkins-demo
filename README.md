# 🚀 Jenkins CI/CD Demo - FastAPI

Modern ve temiz bir Jenkins pipeline demo projesi. 7 aşamalı CI/CD pipeline ile Python FastAPI uygulaması.

## 📋 İçindekiler

- [Özellikler](#özellikler)
- [Pipeline Aşamaları](#pipeline-aşamaları)
- [Kurulum](#kurulum)
- [Yerel Geliştirme](#yerel-geliştirme)
- [Jenkins Kurulumu](#jenkins-kurulumu)
- [Docker Hub Kurulumu](#docker-hub-kurulumu)
- [Proje Yapısı](#proje-yapısı)

## ✨ Özellikler

- 🐍 **FastAPI** - Modern, hızlı Python web framework
- 🧪 **Pytest** - Kapsamlı unit testler (%50+ coverage)
- 🔍 **Flake8** - Code quality ve linting
- 🐳 **Docker** - Containerization
- 📊 **Coverage Report** - HTML coverage raporları
- 📧 **Bildirimler** - Email/Slack entegrasyonu
- 🔄 **CI/CD** - Tam otomatik pipeline

## 🎯 Pipeline Aşamaları

### CI (Continuous Integration) Aşamaları:

### 1️⃣ Checkout
Git repository'den kodu çeker.

### 2️⃣ Install Dependencies
Python bağımlılıklarını yükler:
```bash
pip install -r requirements.txt
```

### 3️⃣ Lint (Code Quality)
Flake8 ile kod kalitesi kontrolü:
```bash
flake8 app/ tests/
```

### 4️⃣ Unit Tests
Pytest ile testleri çalıştırır:
```bash
pytest tests/ --cov=app
```

### 5️⃣ Coverage Check
Minimum %50 coverage kontrolü yapar.

### CD (Continuous Deployment) Aşamaları:

### 6️⃣ Build Docker Image
Docker image'ı build eder ve tag'ler:
```bash
docker build -t yigittq/jenkins-demo-api:BUILD_NUMBER .
docker build -t yigittq/jenkins-demo-api:latest .
```

### 7️⃣ Push to Docker Hub
Docker Hub'a otomatik push eder:
```bash
docker push yigittq/jenkins-demo-api:BUILD_NUMBER
docker push yigittq/jenkins-demo-api:latest
```

### 8️⃣ Deploy
Uygulamayı otomatik deploy eder:
```bash
docker run -d --name jenkins-demo-app -p 8000:8000 yigittq/jenkins-demo-api:latest
```

**Sonuç:** http://localhost:8000 adresinde çalışan uygulama! 🎉

## 🛠️ Kurulum

### Gereksinimler

- Docker & Docker Compose
- Python 3.11+ (sadece yerel development için)
- Git

### 🚀 Hızlı Başlangıç (Docker Compose - ÖNERİLEN)

**Tek komutla her şeyi çalıştır:**

```bash
# 1. Projeyi klonla
git clone <your-repo-url>
cd jenkins-demo2

# 2. Docker Compose ile başlat
docker-compose up -d

# 3. Servis durumlarını kontrol et
docker-compose ps
```

**Erişim URL'leri:**
- 🔧 **Jenkins**: http://localhost:8080
- 🚀 **FastAPI**: http://localhost:8000/docs
- 💚 **Health Check**: http://localhost:8000/health

**İlk Jenkins şifresini al:**
```bash
docker-compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

**Logları izle:**
```bash
# Tüm servisleri izle
docker-compose logs -f

# Sadece Jenkins
docker-compose logs -f jenkins

# Sadece FastAPI
docker-compose logs -f fastapi-app
```

**Durdur ve kaldır:**
```bash
# Sadece durdur
docker-compose stop

# Durdur ve kaldır
docker-compose down

# Her şeyi sil (volumes dahil)
docker-compose down -v
```

### 1. Projeyi Klonla

```bash
git clone <your-repo-url>
cd jenkins-demo2
```

### 2. Virtual Environment Oluştur

```bash
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# veya
venv\Scripts\activate  # Windows
```

### 3. Bağımlılıkları Yükle

```bash
pip install -r requirements.txt
```

## 💻 Yerel Geliştirme

### Uygulamayı Çalıştır

```bash
python -m uvicorn app.main:app --reload
```

Uygulama http://localhost:8000 adresinde çalışacak.

### API Dokümantasyonu

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Testleri Çalıştır

```bash
# Tüm testler
pytest tests/ -v

# Coverage ile
pytest tests/ --cov=app --cov-report=html

# Coverage raporu
open htmlcov/index.html  # Mac
```

### Linting

```bash
flake8 app/ tests/
```

### Docker ile Çalıştır

```bash
# Build
docker build -t jenkins-demo-api .

# Run
docker run -p 8000:8000 jenkins-demo-api
```

## 🔧 Jenkins Kurulumu

### 1. Jenkins Yükle

**Docker ile (Önerilen):**

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

İlk admin şifresini al:
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 2. Jenkins Eklentilerini Yükle

Jenkins'e giriş yap (http://localhost:8080) ve şu eklentileri yükle:

- **Pipeline**
- **Git Plugin**
- **Docker Pipeline**
- **Email Extension Plugin**
- **HTML Publisher**
- **JUnit Plugin**
- **(Opsiyonel) Slack Notification Plugin**

**Dashboard → Manage Jenkins → Plugins → Available plugins**

### 3. Docker Hub Credentials Ekle (CD için gerekli!)

**Dashboard → Manage Jenkins → Credentials → System → Global credentials**

- **Kind:** Username with password
- **Username:** Docker Hub kullanıcı adınız
- **Password:** Docker Hub Access Token (şifre değil!)
- **ID:** `dockerhub-credentials`
- **Description:** Docker Hub Credentials

⚠️ **Önemli:** Güvenlik için Docker Hub şifrenizi değil, Access Token kullanın!

### 4. Email Konfigürasyonu (Opsiyonel)

**Dashboard → Manage Jenkins → System → Extended E-mail Notification**

**Gmail için örnek:**
- **SMTP server:** smtp.gmail.com
- **Port:** 465
- **Use SSL:** ✅
- **Credentials:** Gmail hesabınız + App Password

### 5. Pipeline Job Oluştur

1. **Dashboard → New Item**
2. **Item name:** `jenkins-demo-pipeline`
3. **Type:** Pipeline
4. **Pipeline → Definition:** Pipeline script from SCM
5. **SCM:** Git
6. **Repository URL:** Your Git repository URL
7. **Script Path:** `Jenkinsfile`
8. **Save**

### 6. Jenkinsfile'ı Özelleştir

`Jenkinsfile` dosyasında şu değişiklikleri yap:

```groovy
environment {
    COVERAGE_THRESHOLD = '50'
    DOCKER_IMAGE_NAME = 'yourusername/jenkins-demo-api'  // ⚠️ Docker Hub username'inizi girin!
    DOCKER_REGISTRY = 'docker.io'
    DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'       // Jenkins'teki credential ID
}
```

**Önemli:** `DOCKER_IMAGE_NAME` değişkenini kendi Docker Hub kullanıcı adınızla güncelleyin!

### 7. Pipeline'ı Çalıştır

**Dashboard → jenkins-demo-pipeline → Build Now**

## 🐳 Docker Hub Kurulumu

### 1. Docker Hub Hesabı Oluştur

https://hub.docker.com/ adresinden ücretsiz hesap oluştur.

### 2. Access Token Oluştur

- **Account Settings → Security → New Access Token**
- Token'ı kaydet ve Jenkins credentials'a ekle

### 3. Repository Oluştur (Opsiyonel)

- **Repositories → Create Repository**
- **Name:** `jenkins-demo-api`
- **Visibility:** Public

## 📁 Proje Yapısı

```
jenkins-demo2/
├── app/
│   ├── __init__.py
│   └── main.py              # FastAPI application
├── tests/
│   ├── __init__.py
│   └── test_main.py         # Unit tests
├── docker-compose.yml       # 🆕 Docker Compose orchestration
├── Dockerfile               # Docker image definition
├── Jenkinsfile              # Jenkins pipeline script
├── requirements.txt         # Python dependencies
├── pytest.ini               # Pytest configuration
├── .flake8                  # Flake8 configuration
├── .dockerignore
├── .gitignore
└── README.md
```

## 📊 API Endpoints

### Health Check
```bash
GET /health
```

### Items CRUD
```bash
GET    /items          # List all items
GET    /items/{id}     # Get item by ID
POST   /items          # Create new item
PUT    /items/{id}     # Update item
DELETE /items/{id}     # Delete item
```

### Örnek Request

```bash
# Create item
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Laptop",
    "description": "Gaming laptop",
    "price": 1500.00,
    "in_stock": true
  }'

# Get all items
curl http://localhost:8000/items
```

## 🧪 Test Coverage

Proje minimum %50 test coverage hedefliyor. Mevcut coverage:

- **app/main.py**: %85+
- **Overall**: %50+

Coverage raporu için:
```bash
pytest tests/ --cov=app --cov-report=html
open htmlcov/index.html
```

## 📝 Notlar

### Pipeline Stage'lerini Atlama

Belirli stage'leri atlamak için Jenkinsfile'da `when` bloğunu kullan:

```groovy
stage('Push to Docker Hub') {
    when {
        branch 'main'  // Sadece main branch'te çalış
    }
    steps { ... }
}
```

### Slack Bildirimleri

Jenkinsfile'da Slack notification kodları comment olarak hazır. Kullanmak için:

1. Slack Notification Plugin yükle
2. Slack workspace'e Jenkins app ekle
3. Jenkins'te Slack credentials ekle
4. Jenkinsfile'da comment'leri kaldır

### Sorun Giderme

**Problem:** Docker komutları çalışmıyor
```bash
# Jenkins container'a Docker socket'i mount et
-v /var/run/docker.sock:/var/run/docker.sock
```

**Problem:** Permission denied
```bash
# Jenkins kullanıcısını docker grubuna ekle
docker exec -u root jenkins usermod -aG docker jenkins
docker restart jenkins
```

**Problem:** Coverage threshold failed
```bash
# Coverage threshold'u düşür
environment {
    COVERAGE_THRESHOLD = '30'  # %50'den %30'a düşür
}
```

## 🎓 Öğrenme Kaynakları

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Docker Documentation](https://docs.docker.com/)
- [Pytest Documentation](https://docs.pytest.org/)

## 📧 İletişim

Sorularınız için issue açabilirsiniz.

## 📄 License

MIT License

---

**⭐ Faydalı olduysa star vermeyi unutmayın!**

