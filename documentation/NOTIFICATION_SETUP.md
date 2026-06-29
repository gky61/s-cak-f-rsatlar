# Bildirim Sistemi Kurulumu

## 📱 Mevcut Durum

✅ **Flutter Uygulama Tarafı:**
- Firebase Cloud Messaging (FCM) entegrasyonu tamamlandı
- Kategori ve alt kategori bildirim abonelikleri çalışıyor
- Background notification handler eklendi
- FCM token kaydetme sistemi çalışıyor
- Android bildirim izinleri eklendi

❌ **Backend Tarafı (Gerekli):**
- Firebase Cloud Function ile bildirim gönderme sistemi
- Yeni fırsat eklendiğinde otomatik bildirim gönderme

## 🔔 Bildirim Sistemi Nasıl Çalışıyor?

### 1. Kullanıcı Abonelikleri

**Kategori Bildirimleri:**
- Topic: `category_{categoryId}`
- Örnek: `category_bilgisayar`, `category_mobil_cihazlar`

**Alt Kategori Bildirimleri:**
- Topic: `subcategory_{categoryId}_{subCategoryId}`
- Örnek: `subcategory_bilgisayar_ekran_karti`, `subcategory_mobil_cihazlar_cep_telefonu`

### 2. Kullanıcı Verileri (Firestore)

Kullanıcı dokümanında saklanan veriler:
```javascript
{
  "uid": "user123",
  "fcmToken": "fcm_token_here",
  "followedCategories": ["bilgisayar", "mobil_cihazlar"],
  "followedSubCategories": ["bilgisayar:ekran_karti", "mobil_cihazlar:cep_telefonu"],
  "createdAt": "2025-11-14T00:00:00Z"
}
```

### 3. Yeni Fırsat Eklendiğinde Bildirim Gönderme

**Firebase Cloud Function Gerekli:**

Fırsat eklendiğinde ve onaylandığında, kategori ve alt kategoriye göre bildirim gönderilmesi gerekiyor.

#### Kategori Eşleştirme:

Deal'deki `category` field'ı şu formatta: `"Bilgisayar - Ekran Kartı (GPU)"`

Kategori eşleştirmesi:
1. Ana kategori: `"Bilgisayar"` → Topic: `category_bilgisayar`
2. Alt kategori: `"Bilgisayar - Ekran Kartı (GPU)"` → Topic: `subcategory_bilgisayar_ekran_karti`

## 🔧 Firebase Cloud Function Örneği

### functions/index.js

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Kategori ismini ID'ye çevir
function getCategoryId(categoryName) {
  const categoryMap = {
    'Bilgisayar': 'bilgisayar',
    'Mobil Cihazlar': 'mobil_cihazlar',
    'Konsollar ve Oyun': 'konsol_oyun',
    'Ev Elektroniği ve Yaşam': 'ev_elektronigi_yasam',
    'Ağ ve Yazılım': 'ag_yazilim',
  };
  
  // Kategori ismini bul (örn: "Bilgisayar - Ekran Kartı" → "Bilgisayar")
  for (const [name, id] of Object.entries(categoryMap)) {
    if (categoryName.startsWith(name)) {
      return id;
    }
  }
  return null;
}

// Alt kategori ismini ID'ye çevir
function getSubCategoryId(categoryName, categoryId) {
  const subCategoryMap = {
    'bilgisayar': {
      'Ekran Kartı (GPU)': 'ekran_karti',
      'İşlemci (CPU)': 'islemci',
      'Anakart': 'anakart',
      'RAM (Bellek)': 'ram',
      'SSD & Depolama (M.2, SATA, NVMe)': 'ssd_depolama',
      'Güç Kaynağı (PSU)': 'guc_kaynagi',
      'Bilgisayar Kasası': 'kasa',
    },
    'mobil_cihazlar': {
      'Cep Telefonu (Android, iOS)': 'cep_telefonu',
      'Tablet': 'tablet',
      'Akıllı Saat ve Bileklik': 'akilli_saat_bileklik',
      'Mobil Aksesuarlar (Powerbank, Şarj Cihazı, Kılıf)': 'mobil_aksesuarlar',
    },
    // ... diğer kategoriler
  };
  
  if (!subCategoryMap[categoryId]) return null;
  
  // Alt kategori ismini bul (örn: "Bilgisayar - Ekran Kartı (GPU)" → "Ekran Kartı (GPU)")
  const subCategoryName = categoryName.replace(categoryId + ' - ', '');
  return subCategoryMap[categoryId][subCategoryName] || null;
}

// Yeni fırsat eklendiğinde bildirim gönder
exports.sendDealNotification = functions.firestore
  .document('deals/{dealId}')
  .onCreate(async (snap, context) => {
    const deal = snap.data();
    
    // Sadece onaylanmış fırsatlar için bildirim gönder
    if (!deal.isApproved) {
      console.log('Deal onaylanmadı, bildirim gönderilmedi');
      return null;
    }
    
    const categoryName = deal.category;
    const categoryId = getCategoryId(categoryName);
    
    if (!categoryId) {
      console.log('Kategori bulunamadı:', categoryName);
      return null;
    }
    
    // Ana kategori bildirimi gönder
    const categoryTopic = `category_${categoryId}`;
    const categoryMessage = {
      notification: {
        title: '🔥 Yeni Fırsat!',
        body: `${deal.title} - ${deal.store}`,
      },
      data: {
        dealId: context.params.dealId,
        category: categoryId,
        type: 'category',
      },
      topic: categoryTopic,
    };
    
    try {
      await admin.messaging().send(categoryMessage);
      console.log(`Kategori bildirimi gönderildi: ${categoryTopic}`);
    } catch (error) {
      console.error('Kategori bildirimi hatası:', error);
    }
    
    // Alt kategori varsa, alt kategori bildirimi de gönder
    const subCategoryId = getSubCategoryId(categoryName, categoryId);
    if (subCategoryId) {
      const subCategoryTopic = `subcategory_${categoryId}_${subCategoryId}`;
      const subCategoryMessage = {
        notification: {
          title: '🔥 Yeni Fırsat!',
          body: `${deal.title} - ${deal.store}`,
        },
        data: {
          dealId: context.params.dealId,
          category: categoryId,
          subCategory: subCategoryId,
          type: 'subcategory',
        },
        topic: subCategoryTopic,
      };
      
      try {
        await admin.messaging().send(subCategoryMessage);
        console.log(`Alt kategori bildirimi gönderildi: ${subCategoryTopic}`);
      } catch (error) {
        console.error('Alt kategori bildirimi hatası:', error);
      }
    }
    
    return null;
  });

// Fırsat onaylandığında bildirim gönder
exports.sendDealApprovalNotification = functions.firestore
  .document('deals/{dealId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Eğer fırsat onaylandıysa bildirim gönder
    if (!before.isApproved && after.isApproved) {
      const deal = after;
      const categoryName = deal.category;
      const categoryId = getCategoryId(categoryName);
      
      if (!categoryId) {
        return null;
      }
      
      // Ana kategori bildirimi
      const categoryTopic = `category_${categoryId}`;
      const categoryMessage = {
        notification: {
          title: '🔥 Yeni Fırsat!',
          body: `${deal.title} - ${deal.store}`,
        },
        data: {
          dealId: context.params.dealId,
          category: categoryId,
          type: 'category',
        },
        topic: categoryTopic,
      };
      
      try {
        await admin.messaging().send(categoryMessage);
      } catch (error) {
        console.error('Bildirim hatası:', error);
      }
      
      // Alt kategori bildirimi
      const subCategoryId = getSubCategoryId(categoryName, categoryId);
      if (subCategoryId) {
        const subCategoryTopic = `subcategory_${categoryId}_${subCategoryId}`;
        const subCategoryMessage = {
          notification: {
            title: '🔥 Yeni Fırsat!',
            body: `${deal.title} - ${deal.store}`,
          },
          data: {
            dealId: context.params.dealId,
            category: categoryId,
            subCategory: subCategoryId,
            type: 'subcategory',
          },
          topic: subCategoryTopic,
        };
        
        try {
          await admin.messaging().send(subCategoryMessage);
        } catch (error) {
          console.error('Bildirim hatası:', error);
        }
      }
    }
    
    return null;
  });
```

## 📋 Kurulum Adımları

### 1. Firebase Functions Kurulumu

```bash
# Firebase CLI yükle
npm install -g firebase-tools

# Firebase'e giriş yap
firebase login

# Functions klasörünü başlat
firebase init functions

# Functions dizinine git
cd functions

# Gerekli paketleri yükle
npm install firebase-admin firebase-functions
```

### 2. Functions Kodu

Yukarıdaki `index.js` kodunu `functions/index.js` dosyasına ekleyin.

### 3. Functions'ı Deploy Et

```bash
firebase deploy --only functions
```

## 🎯 Bildirim Gönderme Mantığı

1. **Yeni Fırsat Eklendiğinde:**
   - Fırsat onay bekliyorsa → Bildirim gönderilmez
   - Fırsat onaylandığında → Bildirim gönderilir

2. **Bildirim Konuları:**
   - Ana kategori: `category_{categoryId}`
   - Alt kategori: `subcategory_{categoryId}_{subCategoryId}`

3. **Bildirim İçeriği:**
   - Başlık: "🔥 Yeni Fırsat!"
   - Mesaj: "{deal.title} - {deal.store}"
   - Data: dealId, category, subCategory (varsa)

## ✅ Test

1. Flutter uygulamasında bir kategori/alt kategori için bildirim açın
2. Firebase Console'dan test bildirimi gönderin
3. Yeni bir fırsat ekleyip onaylayın
4. Bildirimin geldiğini kontrol edin

## 🔍 Debug

- Firebase Console > Functions > Logs
- Flutter uygulamasında console logları
- FCM token kontrolü: Firestore > users > {userId} > fcmToken

## 📝 Notlar

- Bildirimler sadece onaylanmış fırsatlar için gönderilir
- Kullanıcılar topic'lere abone olduğunda otomatik bildirim alır
- Uygulama kapalıyken de bildirimler çalışır (background handler)
- Bildirim tıklandığında deal detay sayfasına yönlendirilebilir (gelecek güncelleme)






