# 🤖 Bot Çalışma Mantığı ve Sorunlar

## 📋 Mevcut Bot Mantığı

### 1. **Kanal Listesi**
- `.env` dosyasındaki `TELEGRAM_CHANNELS` değişkeninden kanallar okunuyor
- Örnek: `@indirimkaplani,-3371238729`

### 2. **Son Mesaj ID Takibi**
- Her kanal için son işlenen mesaj ID'si Firebase'de `bot_state` koleksiyonunda saklanıyor
- Format: `{chatIdentifier: "kanal_adi", lastMessageId: 2865, lastUpdated: timestamp}`

### 3. **Yeni Mesaj Çekme**
- Bot her 5 dakikada bir çalışıyor
- Her kanal için:
  1. Son mesaj ID'si Firebase'den alınıyor
  2. `offset_id` parametresi ile yeni mesajlar çekiliyor
  3. **SORUN:** `offset_id` Telethon'da pagination için kullanılıyor, yeni mesajlar için değil!

### 4. **Duplicate Kontrolü**
- Her mesaj işlenmeden önce Firebase'de kontrol ediliyor:
  ```python
  existing_deals = firestore_query('deals', filters=[
      ('telegramMessageId', 'EQUAL', message_id),
      ('telegramChatUsername', 'EQUAL', chat_identifier)
  ])
  ```
- Eğer mesaj zaten varsa, atlanıyor

### 5. **Mesaj İşleme**
- Mesaj parse ediliyor (başlık, link, fiyat)
- Görsel çekiliyor (Telegram media veya linkten)
- Fiyat çekiliyor (linkten veya mesajdan)
- Firebase'e kaydediliyor (`isApproved: false`)

## 🐛 Tespit Edilen Sorunlar

### Sorun 1: `offset_id` Yanlış Kullanılıyor
**Problem:** 
- `offset_id` Telethon'da pagination için kullanılıyor
- Yeni mesajları çekmek için `min_id` kullanılmalı
- Ama `min_id` de çalışmıyor çünkü Telethon'un API'si farklı

**Çözüm:**
- Son N mesajı çekip, ID'ye göre filtrele
- Veya `get_messages` ile son mesajları çekip, ID kontrolü yap

### Sorun 2: Duplicate Kontrolü Çalışmıyor Olabilir
**Problem:**
- REST API query'si yanlış çalışıyor olabilir
- `telegramMessageId` integer olarak kaydediliyor ama query string olarak aranıyor olabilir

**Kontrol:**
- Firebase'de `telegramMessageId` tipini kontrol et
- Query'nin doğru çalıştığını doğrula

### Sorun 3: Son Mesaj ID Yanlış Kaydediliyor
**Problem:**
- Eğer mesajlar işlenirken hata olursa, ID kaydedilmiyor
- Veya yanlış ID kaydediliyor

## ✅ Çözüm: Düzeltilmiş Bot Mantığı

### Yeni Yaklaşım:
1. **Son mesaj ID'sini al**
2. **Son 20 mesajı çek** (limit=20)
3. **Son mesaj ID'sinden büyük olanları filtrele**
4. **Her mesaj için duplicate kontrolü yap**
5. **İşlenen mesajların en büyük ID'sini kaydet**

Bu yaklaşım daha güvenilir çünkü:
- Telethon'un API'sine bağımlı değil
- Her zaman son mesajları çeker
- Duplicate kontrolü her mesaj için yapılır
- Hata durumunda bile son ID doğru kaydedilir


