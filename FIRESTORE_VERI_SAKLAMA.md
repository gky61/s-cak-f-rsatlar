# 📦 Firestore Veri Saklama ve Temizleme Sistemi

## ❓ Soru: URL String'leri Kalıcı mı?

### Kısa Cevap: **HAYIR, Kalıcı Değil** ✅

URL string'leri Firestore'da **kalıcı olarak saklanmıyor**. Otomatik temizleme (cleanup) sistemi var.

---

## 🔄 Otomatik Temizleme Sistemi

### 1. **24 Saatten Eski Onaylanmış Deal'ler** 🔴
**Fonksiyon:** `deleteOldDeals()`

**Ne Yapıyor:**
- 24 saatten eski ve onaylanmış (`isApproved: true`) deal'leri bulur
- Firestore'dan **tamamen siler** (URL string'i dahil)
- Her 6 saatte bir çalışır
- Son temizlik 12 saatten yakınsa tekrar çalışmaz (optimizasyon)

**Kod:**
```dart
// 24 saatten eski onaylanmış deal'leri sil
final cutoffTime = now.subtract(const Duration(hours: 24));
final snapshot = await _firestore
    .collection('deals')
    .where('isApproved', isEqualTo: true)
    .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
    .get();
```

**Sonuç:** URL string'leri **24 saat sonra silinir** ✅

---

### 2. **24 Saatten Eski Onaylanmamış Deal'ler** 🔴
**Fonksiyon:** `deleteUnapprovedDealsAfter24Hours()`

**Ne Yapıyor:**
- 24 saatten eski ve onaylanmamış (`isApproved: false`) deal'leri bulur
- Firestore'dan **tamamen siler** (URL string'i dahil)
- Her 6 saatte bir çalışır
- Son temizlik 1 saatten yakınsa tekrar çalışmaz (optimizasyon)

**Kod:**
```dart
// 24 saatten eski ve onaylanmamış deal'leri sil
final cutoffTime = now.subtract(const Duration(hours: 24));
final snapshot = await _firestore
    .collection('deals')
    .where('isApproved', isEqualTo: false)
    .where('isExpired', isEqualTo: false)
    .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
    .get();
```

**Sonuç:** Onaylanmamış deal'ler **24 saat sonra silinir** ✅

---

### 3. **Süresi Bitmiş Deal'ler** 🟡
**Fonksiyon:** `cleanupExpiredDeals()`

**Ne Yapıyor:**
- `isExpired: true` olan deal'leri bulur
- 1 günden eski olanları Firestore'dan **tamamen siler** (URL string'i dahil)
- Her 6 saatte bir çalışır

**Kod:**
```dart
// isExpired: true olan ve 1 günden eski deal'leri sil
final yesterday = now.subtract(const Duration(days: 1));
final expiredDeals = await _firestore
    .collection('deals')
    .where('isExpired', isEqualTo: true)
    .get();
```

**Sonuç:** Süresi bitmiş deal'ler **1 gün sonra silinir** ✅

---

## ⏰ Temizleme Zamanlaması

### Otomatik Temizleme
- **Sıklık:** Her 6 saatte bir
- **Başlangıç:** Uygulama açıldığında
- **Yer:** `lib/main.dart` → `_MyAppState` → `_runCleanupTasks()`

**Kod:**
```dart
// Her 6 saatte bir kontrol et
_cleanupTimer = Timer.periodic(const Duration(hours: 6), (timer) {
  _runCleanupTasks();
});
```

### Temizleme İşlemleri
1. ✅ `deleteUnapprovedDealsAfter24Hours()` - Onay bekleyen deal'ler
2. ✅ `deleteOldDeals()` - 24 saatten eski deal'ler
3. ✅ `cleanupExpiredDeals()` - Süresi bitmiş deal'ler

---

## 📊 Veri Yaşam Döngüsü

### Senaryo 1: Normal Deal (Onaylanmış)
```
1. Deal oluşturulur → Firestore'a kaydedilir (URL string'i dahil)
2. Admin onaylar → isApproved: true
3. 24 saat geçer → UI'da gösterilmez (client-side filtreleme)
4. 24 saat + 6 saat (cleanup çalışana kadar) → Firestore'da hala var
5. Cleanup çalışır → Firestore'dan TAMAMEN silinir (URL string'i dahil)
```

**Toplam Süre:** Maksimum 30 saat (24 saat + 6 saat cleanup gecikmesi)

### Senaryo 2: Onaylanmamış Deal
```
1. Deal oluşturulur → Firestore'a kaydedilir (URL string'i dahil)
2. Admin onaylamaz → isApproved: false
3. 24 saat geçer → Cleanup çalışır
4. Firestore'dan TAMAMEN silinir (URL string'i dahil)
```

**Toplam Süre:** Maksimum 30 saat (24 saat + 6 saat cleanup gecikmesi)

### Senaryo 3: Süresi Bitmiş Deal
```
1. Deal oluşturulur → Firestore'a kaydedilir (URL string'i dahil)
2. Kullanıcı "Süresi Bitti" oyu verir → isExpired: true
3. 1 gün geçer → Cleanup çalışır
4. Firestore'dan TAMAMEN silinir (URL string'i dahil)
```

**Toplam Süre:** Maksimum 1 gün + 6 saat

---

## 💾 Firestore Depolama Maliyeti

### URL String Boyutu
- Ortalama URL uzunluğu: ~100-200 karakter
- Her karakter: 1 byte
- **Ortalama deal URL boyutu:** ~150 byte

### Hesaplama
```
Varsayımlar:
- Günde 100 deal paylaşımı
- Her deal: 150 byte URL + diğer veriler (~500 byte toplam)
- Toplam deal boyutu: ~500 byte

24 saat içinde:
- 100 deal × 500 byte = 50 KB
- Firestore ücretsiz kotası: 1 GB
- 50 KB << 1 GB → ÜCRETSİZ ✅

30 saat içinde (cleanup öncesi):
- 100 deal × 500 byte = 50 KB
- Hala ücretsiz kotada ✅
```

### Sonuç
- **24 saat içindeki deal'ler:** ~50-100 KB (ücretsiz)
- **Cleanup sonrası:** Veriler silinir, depolama azalır
- **Aylık maliyet:** $0 (1 GB ücretsiz kotada)

---

## 🔍 Client-Side vs Server-Side Filtreleme

### Client-Side Filtreleme (UI'da Gösterme)
**Ne Yapıyor:**
- 24 saatten eski deal'leri UI'da **göstermez**
- Firestore'dan veri çekilir ama filtrelenir
- **Firestore'da hala var** (cleanup çalışana kadar)

**Kod:**
```dart
// Client-side'da filtrele
final cutoffTime = now.subtract(const Duration(hours: 24));
final deals = snapshot.docs
    .map((doc) => Deal.fromFirestore(doc))
    .where((deal) => deal.createdAt.isAfter(cutoffTime))
    .toList();
```

### Server-Side Temizleme (Firestore'dan Silme)
**Ne Yapıyor:**
- 24 saatten eski deal'leri Firestore'dan **tamamen siler**
- URL string'i dahil tüm veriler silinir
- Her 6 saatte bir çalışır

**Kod:**
```dart
// Server-side'da sil
final snapshot = await _firestore
    .collection('deals')
    .where('isApproved', isEqualTo: true)
    .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
    .get();
    
for (var doc in snapshot.docs) {
  batch.delete(doc.reference); // TAMAMEN sil
}
```

---

## ✅ Özet

### URL String'leri Kalıcı mı?
**HAYIR** ❌

### Ne Zaman Silinir?
1. **Onaylanmış deal'ler:** 24 saat sonra (maksimum 30 saat)
2. **Onaylanmamış deal'ler:** 24 saat sonra (maksimum 30 saat)
3. **Süresi bitmiş deal'ler:** 1 gün sonra

### Temizleme Sıklığı
- **Her 6 saatte bir** otomatik temizleme
- Uygulama açıldığında da çalışır

### Firestore Depolama
- **24 saat içindeki deal'ler:** ~50-100 KB (ücretsiz)
- **Cleanup sonrası:** Veriler silinir
- **Aylık maliyet:** $0 (1 GB ücretsiz kotada)

### Sonuç
✅ **URL string'leri kalıcı değil**  
✅ **Otomatik temizleme sistemi var**  
✅ **Maliyet: $0** (ücretsiz kotada)  
✅ **Veriler maksimum 30 saat içinde silinir**

---

## 🔧 İyileştirme Önerileri

### 1. Daha Sık Temizleme
Şu an: Her 6 saatte bir  
Öneri: Her 1 saatte bir (daha hızlı temizleme)

### 2. Cloud Functions ile Temizleme
Şu an: Client-side'da çalışıyor  
Öneri: Cloud Functions ile server-side'da çalıştır (daha güvenilir)

### 3. Firestore TTL (Time To Live)
Şu an: Manuel temizleme  
Öneri: Firestore TTL kullan (otomatik silme)

---

## 📝 Notlar

1. **Cleanup gecikmesi:** Maksimum 6 saat (cleanup çalışana kadar)
2. **Veri kaybı yok:** Cleanup sadece eski verileri siler
3. **Performans:** Batch işlemleri kullanılıyor (500'lük gruplar)
4. **Optimizasyon:** Gereksiz cleanup'lar önleniyor (son temizlik kontrolü)

