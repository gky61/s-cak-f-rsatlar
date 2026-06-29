# Firebase Cloud Functions Kurulum Rehberi

## 📋 Önkoşullar

### 1. Node.js Güncellemesi (Gerekli)

Firebase CLI v14.25.0 ve üzeri için **Node.js 20 veya üzeri** gereklidir.

**Mevcut Node.js Sürümünüz:** v18.20.8 (Güncelleme gerekli)

#### Node.js Güncelleme Seçenekleri:

**Seçenek 1: nvm (Node Version Manager) kullanarak (Önerilen)**
```bash
# nvm kurulumu (macOS/Linux)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Terminal'i yeniden başlat veya:
source ~/.zshrc

# Node.js 20 LTS kurulumu
nvm install 20
nvm use 20
nvm alias default 20

# Kontrol et
node --version  # v20.x.x olmalı
```

**Seçenek 2: Doğrudan Node.js İndirme**
1. https://nodejs.org/ adresine git
2. LTS versiyonunu (v20.x.x) indir ve kur
3. Terminal'i yeniden başlat

**Seçenek 3: Homebrew (macOS)**
```bash
brew install node@20
brew link node@20 --force
```

### 2. Firebase CLI Kurulumu

Node.js 20 kurulduktan sonra:
```bash
npm install -g firebase-tools@latest
firebase --version  # v14.25.0 veya üzeri olmalı
```

### 3. Firebase'e Giriş

```bash
firebase login
```

Tarayıcı açılacak, Firebase hesabınızla giriş yapın.

## 🚀 Kurulum Adımları

### 1. Functions Klasörüne Git

```bash
cd functions
```

### 2. NPM Paketlerini Yükle

```bash
npm install
```

Bu komut şu paketleri yükleyecek:
- `firebase-admin`: Firebase Admin SDK (bildirim gönderme için)
- `firebase-functions`: Firebase Cloud Functions SDK

### 3. Firebase Projesini Kontrol Et

Proje ID'niz: `sicak-firsatlar-e6eae`

Kontrol etmek için:
```bash
firebase projects:list
```

Eğer proje listede görünmüyorsa:
```bash
firebase use sicak-firsatlar-e6eae
```

### 4. Functions'ı Test Et (Opsiyonel - Local Emulator)

```bash
# Functions klasöründe
npm run serve
```

Bu komut local Firebase emulator'ü başlatır ve Functions'ı test edebilirsiniz.

### 5. Functions'ı Deploy Et

```bash
# Proje root klasöründe
firebase deploy --only functions
```

Veya sadece belirli bir function'ı deploy etmek için:
```bash
firebase deploy --only functions:sendDealNotification
firebase deploy --only functions:sendDealApprovalNotification
```

## 📁 Dosya Yapısı

```
SICAK FIRSATLAR/
├── functions/
│   ├── index.js          # Cloud Functions kodu
│   ├── package.json      # NPM bağımlılıkları
│   ├── .eslintrc.js      # ESLint yapılandırması
│   └── .gitignore        # Git ignore dosyası
├── firebase.json         # Firebase yapılandırması
└── .firebaserc           # Firebase proje yapılandırması
```

## 🔔 Functions Açıklaması

### 1. `sendDealNotification`
- **Tetiklenme:** Yeni bir deal oluşturulduğunda
- **Aksiyon:** Eğer deal onaylanmışsa (`isApproved: true`), kategori ve alt kategori topic'lerine bildirim gönderir

### 2. `sendDealApprovalNotification`
- **Tetiklenme:** Bir deal güncellendiğinde (`isApproved: false` → `true`)
- **Aksiyon:** Kategori ve alt kategori topic'lerine bildirim gönderir

## 📊 Bildirim Topic Yapısı

### Kategori Bildirimleri
- Topic formatı: `category_{categoryId}`
- Örnekler:
  - `category_bilgisayar`
  - `category_mobil_cihazlar`
  - `category_konsol_oyun`

### Alt Kategori Bildirimleri
- Topic formatı: `subcategory_{categoryId}_{subCategoryId}`
- Örnekler:
  - `subcategory_bilgisayar_ekran_karti`
  - `subcategory_mobil_cihazlar_cep_telefonu`
  - `subcategory_konsol_oyun_konsollar`

## 🧪 Test Etme

### 1. Firebase Console'dan Test

1. Firebase Console > Functions bölümüne git
2. Function'ları kontrol et (deploy edildiklerini gör)
3. Logs bölümünden function loglarını izle

### 2. Flutter Uygulamasından Test

1. Flutter uygulamasında bir kategori/alt kategori için bildirim aç
2. Admin ekranından yeni bir fırsat ekle ve onayla
3. Bildirimin geldiğini kontrol et

### 3. Firestore'dan Test

1. Firebase Console > Firestore
2. `deals` koleksiyonuna yeni bir document ekle:
   ```json
   {
     "title": "Test Fırsat",
     "store": "Test Mağaza",
     "category": "Bilgisayar - Ekran Kartı (GPU)",
     "isApproved": true,
     "createdAt": "2025-01-14T00:00:00Z"
   }
   ```
3. Function'ın tetiklendiğini ve bildirim gönderildiğini kontrol et

## 🔍 Debug

### Function Loglarını İzleme

```bash
# Tüm function loglarını izle
firebase functions:log

# Belirli bir function'ın loglarını izle
firebase functions:log --only sendDealNotification
```

### Firebase Console'dan Log İzleme

1. Firebase Console > Functions
2. İlgili function'ı seç
3. "Logs" sekmesine git
4. Gerçek zamanlı logları izle

## ⚠️ Önemli Notlar

1. **Node.js Versiyonu:** Functions için Node.js 18 kullanıyoruz (package.json'da belirtildi). Bu, Firebase Cloud Functions'un desteklediği bir versiyondur.

2. **Firebase Admin SDK:** `firebase-admin` otomatik olarak Firebase projenize bağlanır. Ekstra yapılandırma gerekmez.

3. **Bildirim Gönderme:** Functions, Firebase Cloud Messaging (FCM) topic'lerine bildirim gönderir. Kullanıcılar Flutter uygulamasında bu topic'lere abone olur.

4. **Maliyet:** Cloud Functions kullanımı Firebase ücretsiz kotası dahilindedir. Aşırı kullanımda ücretlendirme yapılabilir.

5. **Bölge:** Functions varsayılan olarak `us-central1` bölgesinde çalışır. Türkiye için daha iyi performans için `europe-west1` (Belgium) veya `europe-west3` (Frankfurt) kullanabilirsiniz.

## 🔧 Bölge Değiştirme (Opsiyonel)

Daha iyi performans için Functions'ı Avrupa bölgesine taşıyabilirsiniz:

`functions/index.js` dosyasında:
```javascript
const functions = require('firebase-functions').region('europe-west3');

exports.sendDealNotification = functions
  .region('europe-west3')
  .firestore
  .document('deals/{dealId}')
  .onCreate(async (snap, context) => {
    // ... kod
  });
```

## 📝 Sonraki Adımlar

1. ✅ Node.js'i 20'ye güncelle
2. ✅ Firebase CLI'yi kur
3. ✅ Firebase'e giriş yap
4. ✅ Functions paketlerini yükle
5. ✅ Functions'ı deploy et
6. ✅ Test et

## 🆘 Sorun Giderme

### "Node.js version incompatible" hatası
- Node.js'i 20'ye güncelleyin (yukarıdaki talimatlara bakın)

### "Firebase login" hatası
- `firebase logout` yapın, sonra `firebase login` yapın
- Tarayıcıda Firebase hesabınızla giriş yapın

### "Permission denied" hatası
- Firebase Console > IAM & Admin > IAM bölümünden yetkilerinizi kontrol edin
- Functions için gerekli yetkilere sahip olduğunuzdan emin olun

### "Functions deploy" hatası
- `firebase projects:list` ile projenizi kontrol edin
- `.firebaserc` dosyasında proje ID'nin doğru olduğundan emin olun
- `firebase use sicak-firsatlar-e6eae` ile projeyi seçin

### Bildirimler gelmiyor
- Flutter uygulamasında bildirim izinlerinin açık olduğundan emin olun
- FCM token'ın Firestore'da kayıtlı olduğundan emin olun
- Kullanıcının ilgili topic'lere abone olduğundan emin olun
- Function loglarını kontrol edin

## 📚 Kaynaklar

- [Firebase Cloud Functions Dokümantasyonu](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging Dokümantasyonu](https://firebase.google.com/docs/cloud-messaging)
- [Firebase CLI Dokümantasyonu](https://firebase.google.com/docs/cli)






