# Firebase Cloud Functions

Bu klasör, Sıcak Fırsatlar uygulaması için Firebase Cloud Functions içerir.

## 📋 Kurulum

### 1. Node.js Güncellemesi (Gerekli)

Firebase CLI için **Node.js 20 veya üzeri** gereklidir.

```bash
# nvm kullanarak (önerilen)
nvm install 20
nvm use 20

# veya doğrudan https://nodejs.org/ adresinden indirin
```

### 2. NPM Paketlerini Yükle

```bash
cd functions
npm install
```

### 3. Firebase'e Giriş

```bash
firebase login
```

### 4. Functions'ı Deploy Et

```bash
# Proje root klasöründe
firebase deploy --only functions
```

## 🔔 Functions

### `sendDealNotification`
- **Tetiklenme:** Yeni bir deal oluşturulduğunda
- **Aksiyon:** Onaylanmış deal'ler için kategori ve alt kategori topic'lerine bildirim gönderir

### `sendDealApprovalNotification`
- **Tetiklenme:** Bir deal onaylandığında (`isApproved: false` → `true`)
- **Aksiyon:** Kategori ve alt kategori topic'lerine bildirim gönderir

## 📊 Topic Yapısı

- Kategori: `category_{categoryId}` (örn: `category_bilgisayar`)
- Alt Kategori: `subcategory_{categoryId}_{subCategoryId}` (örn: `subcategory_bilgisayar_ekran_karti`)

## 🧪 Test

### Local Emulator
```bash
npm run serve
```

### Log İzleme
```bash
firebase functions:log
```

## 📚 Daha Fazla Bilgi

Detaylı kurulum talimatları için `FIREBASE_FUNCTIONS_SETUP.md` dosyasına bakın.






