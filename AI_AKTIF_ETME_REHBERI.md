# 🤖 AI Özelliklerini Aktif Etme Rehberi

## ✅ Yapılan Düzeltmeler

### 1. Model Adları Düzeltildi
**Sorun:** `gemini-1.5-flash-latest` model adı bulunamıyordu.

**Çözüm:** Doğru model adları kullanıldı:
```python
model_names = ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-pro']
```

### 2. Hata Yakalama İyileştirildi
- Daha detaylı hata logları eklendi
- API key kontrolü eklendi
- Her adımda hata yakalama iyileştirildi

## 🔍 AI Özelliklerinin Çalışıp Çalışmadığını Kontrol Etme

### 1. Bot Loglarını Kontrol Et

```bash
ssh -i ~/Desktop/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd /home/ubuntu/sicak_firsatlar_bot && tail -50 logs/bot.log | grep -E 'Gemini|AI modeli'"
```

**Beklenen Çıktı:**
```
✅ Gemini AI modeli yüklendi: gemini-1.5-flash
```

### 2. AI Analiz Loglarını Kontrol Et

```bash
ssh -i ~/Desktop/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd /home/ubuntu/sicak_firsatlar_bot && tail -100 logs/bot.log | grep -E 'AI analizi|Kategori.*AI|Fiyat.*AI'"
```

**Başarılı AI Analizi:**
```
🤖 AI analizi başlatılıyor (görsel ve metin analizi)...
📸 Görsel AI'ye gönderiliyor (OCR ile fiyat okuma)...
📝 AI response (ilk 500 karakter): {"title": "...", "price": 1234.5, "category": "elektronik", "store": "Amazon"}
✅ AI analizi tamamlandı: {'title': '...', 'price': 1234.5, 'category': 'elektronik', 'store': 'Amazon'}
💰 Fiyat AI'dan çıkarıldı: 1234.5 TL
📂 Kategori görselden (AI) çıkarıldı: elektronik
```

**Başarısız AI Analizi:**
```
🤖 AI analizi başlatılıyor (görsel ve metin analizi)...
❌ AI hatası: 404 models/...
⚠️ AI analizi başarısız, temel veri kullanılıyor
```

### 3. GEMINI_API_KEY Kontrolü

```bash
ssh -i ~/Desktop/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd /home/ubuntu/sicak_firsatlar_bot && cat .env | grep GEMINI_API_KEY"
```

**Beklenen Çıktı:**
```
GEMINI_API_KEY=AIzaSy...
```

## 🛠️ Sorun Giderme

### Problem 1: "AI modeli yok" Hatası

**Kontrol:**
```bash
# .env dosyasında GEMINI_API_KEY var mı?
ssh -i ~/Desktop/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd /home/ubuntu/sicak_firsatlar_bot && cat .env | grep GEMINI_API_KEY"
```

**Çözüm:**
1. `.env` dosyasına `GEMINI_API_KEY=your_api_key_here` ekleyin
2. Botu yeniden başlatın

### Problem 2: "404 models/..." Hatası

**Kontrol:**
```bash
# Bot loglarında model hatası var mı?
ssh -i ~/Desktop/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd /home/ubuntu/sicak_firsatlar_bot && tail -100 logs/bot.log | grep '404 models'"
```

**Çözüm:**
1. Model adlarının doğru olduğundan emin olun
2. Google Gemini API dokümantasyonunu kontrol edin
3. API key'in geçerli olduğundan emin olun

### Problem 3: "AI analizi başarısız" Uyarısı

**Kontrol:**
```bash
# Detaylı hata loglarını kontrol et
ssh -i ~/Desktop/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd /home/ubuntu/sicak_firsatlar_bot && tail -200 logs/bot.log | grep -A 5 'AI hatası'"
```

**Olası Nedenler:**
- API key geçersiz veya süresi dolmuş
- API quota aşıldı
- Model adı yanlış
- Network hatası

**Çözüm:**
1. API key'i kontrol edin
2. Google Cloud Console'da quota'yı kontrol edin
3. Botu yeniden başlatın

## 📊 AI Özellikleri Test Etme

### Test 1: Basit Mesaj Testi

Bir Telegram kanalına şu formatta mesaj gönderin:
```
Ürün Adı: iPhone 15 Pro
Fiyat: 45.999 TL
Link: https://example.com/product
```

**Beklenen Sonuç:**
- AI kategori tespit eder: `elektronik`
- AI fiyat çıkarır: `45999.0`
- AI ürün adını belirler

### Test 2: Görsel Testi

Bir Telegram kanalına görsel içeren mesaj gönderin (fiyat görselde yazılı).

**Beklenen Sonuç:**
- AI görselden fiyat okur (OCR)
- AI görselden kategori tespit eder
- AI görselden ürün adını çıkarır

## ✅ AI Özelliklerinin Aktif Olduğunu Doğrulama

AI özellikleri aktifse şunları görmelisiniz:

1. **Bot Başlangıçta:**
   ```
   ✅ Gemini AI modeli yüklendi: gemini-1.5-flash
   ```

2. **Mesaj İşlenirken:**
   ```
   🤖 AI analizi başlatılıyor (görsel ve metin analizi)...
   ✅ AI analizi tamamlandı: {...}
   💰 Fiyat AI'dan çıkarıldı: ...
   📂 Kategori görselden (AI) çıkarıldı: ...
   ```

3. **Firebase'e Kayıt:**
   - Kategori doğru tespit edilmiş olmalı
   - Fiyat doğru çıkarılmış olmalı
   - Ürün adı düzgün belirlenmiş olmalı

## 🎯 Sonuç

AI özellikleri şu şekilde aktif olmalı:
- ✅ Model yüklendi
- ✅ API key geçerli
- ✅ Mesajlar işlenirken AI analizi yapılıyor
- ✅ Kategori, fiyat, ürün adı doğru tespit ediliyor

**Not:** Eğer hala çalışmıyorsa, logları kontrol edip hata mesajlarını paylaşın.



