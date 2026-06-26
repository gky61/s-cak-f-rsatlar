# 🤖 Real-Time Telegram Bot - Google Cloud Run

Bu bot **7/24 çalışır** ve Telegram kanallarını **gerçek zamanlı dinler**.

## ✨ Özellikler

- ✅ **Real-time mesaj yakalama** - Yeni mesaj gelir gelmez yakalar
- ✅ **Link filtreleme** - Sadece link içeren mesajları işler
- ✅ **Firebase entegrasyonu** - Direkt Firestore'a kaydeder
- ✅ **Otomatik yeniden bağlanma** - Bağlantı koparsa otomatik tekrar bağlanır
- ✅ **Health check** - Servis sağlığı izlenebilir
- ✅ **Docker containerized** - Kolay deploy ve scaling

## 📋 Gereksinimler

1. **Google Cloud SDK** (gcloud CLI)
2. **Docker**
3. **Telegram API credentials**
4. **Firebase service account**

## 🚀 Kurulum

### 1. Google Cloud SDK Kurulumu

**Mac için:**
```bash
# Homebrew ile kur
brew install --cask google-cloud-sdk

# Giriş yap
gcloud auth login

# Docker için authentication
gcloud auth configure-docker

# Projeyi ayarla
gcloud config set project sicak-firsatlar-e6eae
```

### 2. Environment Variables Ayarla

```bash
export TELEGRAM_API_ID="37462587"
export TELEGRAM_API_HASH="35c8bc7cd010dd61eb5a123e2722be41"
export TELEGRAM_SESSION_STRING="1BAAOMTQ5Lj..."
export TELEGRAM_CHANNELS="@indirimkaplani,-3371238729"
```

### 3. Deploy Et

```bash
cd cloud-run-bot
chmod +x deploy.sh
./deploy.sh
```

## 📊 Kontrol ve İzleme

### Servis Durumu
```bash
gcloud run services describe telegram-bot \
  --region us-central1 \
  --project sicak-firsatlar-e6eae
```

### Logları İzle
```bash
gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=telegram-bot" \
  --project sicak-firsatlar-e6eae
```

### Health Check
```bash
# Servis URL'sini al
SERVICE_URL=$(gcloud run services describe telegram-bot --region us-central1 --project sicak-firsatlar-e6eae --format='value(status.url)')

# Health check yap
curl ${SERVICE_URL}/health
```

## 🛑 Durdurma

```bash
# Servisi sil
gcloud run services delete telegram-bot \
  --region us-central1 \
  --project sicak-firsatlar-e6eae
```

## 💰 Maliyet

Cloud Run pricing:
- **CPU:** $0.00002400/vCPU-second
- **Memory:** $0.00000250/GiB-second
- **Request:** $0.40/million requests

**Tahmini aylık maliyet:** $5-10
- 1 instance sürekli çalışır
- 512MB RAM
- 1 vCPU

## 🔧 Sorun Giderme

### Bot başlamıyor:
```bash
# Logları kontrol et
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=telegram-bot" \
  --limit 50 \
  --project sicak-firsatlar-e6eae
```

### Telegram bağlantısı kopuyor:
- Session string'i güncelleyin
- API credentials'ları kontrol edin

### Firebase hatası:
- Service account permissions kontrol edin
- Firestore rules kontrol edin

## 📝 Notlar

- Bot **minimum 1 instance** ile çalışır (her zaman aktif)
- Mesajlar **anında** Firebase'e kaydedilir
- Duplicate kontrolü yapılır
- Admin onayı bekler (`isApproved: false`)
