# 📊 Kurulum Durumu

## ✅ Hazır Olanlar

- ✅ **Kod hazır**: Telegram bot kodu yazıldı (grup + kanal desteği)
- ✅ **Parser hazır**: Mesaj parse fonksiyonu çalışıyor
- ✅ **Firestore entegrasyonu**: Deal kaydetme hazır
- ✅ **Dokümantasyon**: Tüm rehberler hazır
- ✅ **Test araçları**: Test script'leri hazır

## ⚠️ Yapılması Gerekenler

### 1. Telegram Bot Oluşturma
- [ ] BotFather'dan bot oluştur
- [ ] Bot token'ını al

### 2. Paketleri Yükleme
```bash
cd functions
npm install
cd ..
```

### 3. Firebase Config Ayarlama
```bash
firebase functions:config:set telegram.bot_token="BOT_TOKEN_BURAYA"
firebase functions:config:set telegram.allowed_channels="@donanimhabersicakfirsatlar"
```

### 4. Function Deploy
```bash
firebase deploy --only functions:telegramWebhook
```

### 5. Webhook Ayarlama
```bash
# Deploy sonrası alınan URL ile:
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "WEBHOOK_URL_BURAYA"}'
```

### 6. Bot'u Kanala Ekleme
- [ ] @donanimhabersicakfirsatlar kanalına git
- [ ] Bot'u admin olarak ekle

## 🚀 Hızlı Kurulum

Tüm adımları otomatik yapmak için:

```bash
./setup_telegram_bot.sh
```

Script size soracak:
1. Bot Token
2. Grup ID'leri (opsiyonel)
3. Kanal username'leri: `@donanimhabersicakfirsatlar`





