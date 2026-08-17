# 📦 Firestore Veri Saklama ve Temizleme Sistemi

## ❓ Soru: Fırsat ve URL Verileri Ne Kadar Süre Saklanır?

### 📌 Kısa Cevap: **30 Günlük Kademeli Retansiyon Sistemi** ✅

FırsatKolik'te fırsatlar ve görseller kullanıcı deneyimi (UX) ve favori arşivi için **30 gün boyunca** korunur; 30 gün dolduğunda otomatik temizlik (Purge Job) sistemiyle kalıcı olarak temizlenir.

---

## 🔄 3 Kademeli Veri Yaşam Döngüsü

```
[Yeni Fırsat Paylaşıldı]
       │
       ├─► 0 - 48 Saat ────────► Anasayfa, Favori Kategorilerim ve Popüler'de Canlı
       │
       ├─► 48 Saat Sonrası ────► cleanupExpiredDeals (Her gün 03:00)
       │                         • Fırsat veritabanından SİLİNMEZ!
       │                         • Sadece `isExpired: true` olarak işaretlenir (Soft-Expire).
       │                         • Anasayfa ve Popüler akışlarından düşer.
       │                         • Favorilerde orijinal görseli, fiyatı ve "⌛ KAÇTI" rozetiyle 30 gün kalır.
       │
       └─► 30 Gün Sonrası ─────► purgeOldDeals (Her Pazar 04:00 veya Web Admin "30+ Günlük Temizlik")
                                 • Fırsat dokümanı, oylar, yorumlar, Storage görselleri ve 
                                   tüm kullanıcı favorileri KALICI OLARAK SİLİNİR (Hard-Purge) 🗑️
```

---

## ⚙️ Backend Temizleme Görevleri (Cloud Functions)

### 1. **48 Saatlik Süresi Doldu İşaretleme** 🟡
**Fonksiyon:** `cleanupExpiredDeals` (Her gün gece 03:00)
- 48 saatten eski olan aktif fırsatları bulur.
- Dokümanı **SİLMEZ**, sadece `isExpired: true` ve `expiredAt` günceller.
- Böylece anasayfa ve popüler akışlarından düşürülürken, kullanıcının favorilerinde arşiv olarak korunur.

### 2. **30 Günlük Kalıcı Silme (Derin Temizlik / Purge)** 🔴
**Fonksiyon:** `purgeOldDeals` (Her Pazar 04:00) & Web Admin `purgeOldDealsWeb()`
- 30 günden eski fırsatları bulur.
- Firestore'dan **tamamen siler**:
  1. `deals/{dealId}` (Ana fırsat dokümanı)
  2. `deals/{dealId}/votes/*` (Oylar)
  3. `deals/{dealId}/comments/*` (Yorumlar)
  4. `users/{userId}/favorites/{dealId}` (Kullanıcıların favori referansları)
  5. Firebase Storage üzerindeki görsel dosyaları

### 3. **30 Günlük Görsel Temizliği** 📷
**Fonksiyon:** `cleanupOldImages` (Her gün gece 00:00)
- Firebase Storage `deals/` dizinindeki 30 günden eski görselleri temizler.

---

## 💾 Favori Snapshot Garantisi (`UserService.addToFavorites`)

Kullanıcı bir fırsatı favorilerine kaydettiği anda (`addToFavorites`), fırsatın:
- `title` (Başlık)
- `price` (Fiyat)
- `store` (Mağaza Adı)
- `link` (Ürün Linki)
- `imageUrl` (Ürün Görsel URL'si)
alanları `users/{userId}/favorites/{dealId}` altına snapshot olarak yazılır.

Bu sayede 30 günlük süreç boyunca ana dokümanda herhangi bir geçici durum oluşsa dahi kullanıcının favorilerinde orijinal ürün görseli asla kaybolmaz ve mağaza logosuna dönüşmez.

---

## ✅ Özet

- **0-48 Saat:** Canlı ve vitrinde.
- **48 Saat - 30 Gün:** Favorilerde arşiv olarak orijinal görseli ve "KAÇTI" rozetiyle yaşar.
- **30 Gün Sonrası:** Tüm ilişkili verilerle birlikte kalıcı olarak temizlenir (Purge).
