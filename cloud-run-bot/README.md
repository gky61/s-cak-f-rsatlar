# 🤖 FırsatKolik — Otonom Telegram Botu & Web Kazıma Servisi

Bu servis, Telegram indirim kanallarını MTProto üzerinden **7/24 gerçek zamanlı dinleyen**, yakalanan linkleri gelişmiş WAF bypass yöntemleriyle kazıyan, yapay zeka ile kategorize eden ve Firestore veritabanına aktaran Node.js uygulamasıdır.

---

## 🏗️ Altyapı ve Barındırma
Bot, **Google Cloud Compute Engine** üzerindeki ücretsiz katman sanal makinede (`telegram-bot-server`, `e2-micro`, `us-central1-a`) Docker konteynerleri olarak çalışmaktadır:

* **DEV Bot Konteyneri (`dev-bot`):** Port `8081` -> `8080`, Firestore: `sicak-firsatlar-e6eae`
* **PROD Bot Konteyneri (`prod-bot`):** Port `8082` -> `8080`, Firestore: `firsatkolik-prod-e6eae`

---

## 🚀 Dağıtım (Deployment)

### 1. Standart Bulut Derlemeli Dağıtım (Cloud Build):
```bash
# DEV Botunu Güncelle
python deploy_to_vm.py dev

# PROD Botunu Güncelle
python deploy_to_vm.py prod
```

### 2. Doğrudan VM İçi Derlemeli Dağıtım (Cloud Build Bypass / Sıfır Maliyet):
```bash
# DEV Botunu Doğrudan VM'de Derle
python deploy_direct_vm.py dev

# PROD Botunu Doğrudan VM'de Derle
python deploy_direct_vm.py prod
```

---

## 🔍 Sağlık ve Log Kontrolü

```bash
# Sağlık Kontrolü (Health Check)
curl http://34.135.181.112:8081/health  # DEV
curl http://34.135.181.112:8082/health  # PROD

# VM İçerisinde Canlı Logları İzleme (SSH)
gcloud compute ssh telegram-bot-server --zone=us-central1-a --project=firsatkolik-prod-e6eae
sudo docker logs -f dev-bot --tail 100
sudo docker logs -f prod-bot --tail 100
```

---

## 📚 Detaylı Dokümantasyon
Tüm WAF bypass stratejileri, kazıma kuralları ve mimari akışlar için ana dokümanları inceleyiniz:
* 👉 [Cloud Run Telegram Bot Scraping Kuralları ve Stratejileri](file:///d:/firsatkolik/documentation/scraping-ve-botlar/bot_scraping_rules_and_strategies.md)
* 👉 [Uçtan Uca Scraping Mimarisi ve Doğrulama Akışları](file:///d:/firsatkolik/documentation/scraping-ve-botlar/end_to_end_scraping_architecture.md)
* 👉 [Google Cloud Maliyet Analizi ve Free Tier VM Mimarisi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/google_cloud_cost_analysis.md)
