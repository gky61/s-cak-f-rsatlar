# 🔥 Firebase Functions Deploy - Detaylı Adım Adım Rehber

## 📋 İçindekiler
1. [Gereksinimler Kontrolü](#gereksinimler-kontrolü)
2. [Firebase'e Giriş Yapma](#firebasee-giriş-yapma)
3. [Functions'ı Deploy Etme](#functionsı-deploy-etme)
4. [Sorun Giderme](#sorun-giderme)

---

## 1. Gereksinimler Kontrolü

### ✅ Adım 1.1: Terminal'i Açın

**macOS'ta:**
- `Cmd + Space` tuşlarına basın
- "Terminal" yazın ve Enter'a basın
- Veya Applications > Utilities > Terminal

### ✅ Adım 1.2: Proje Klasörüne Gidin

Terminal'de şu komutu yazın ve Enter'a basın:

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
```

**Kontrol:** Proje klasöründeyken şu komutla kontrol edebilirsiniz:
```bash
ls -la
```
`functions`, `lib`, `pubspec.yaml` gibi dosyaları görmelisiniz.

### ✅ Adım 1.3: Node.js Versiyonunu Kontrol Edin

Şu komutu çalıştırın:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
node --version
```

**Beklenen çıktı:** `v20.19.5` (veya benzeri v20.x.x)

Eğer farklı bir versiyon görürseniz:
```bash
nvm use 20
```

---

## 2. Firebase'e Giriş Yapma

### 📝 Adım 2.1: Firebase Login Komutunu Çalıştırın

Terminal'de şu komutları sırayla yazın (her birini Enter'a basarak):

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
firebase login
```

### 🌐 Adım 2.2: Tarayıcı Açılacak

Komutu çalıştırdıktan sonra:

1. **Terminal'de şöyle bir mesaj göreceksiniz:**
   ```
   ? Allow Firebase to collect anonymous CLI usage and error reporting information? (Y/n)
   ```
   - İsterseniz `Y`, istemezseniz `n` yazıp Enter'a basın (önerilen: `Y`)

2. **Ardından şu mesajı göreceksiniz:**
   ```
   Visit this URL on this device to log in:
   https://accounts.google.com/o/oauth2/auth?client_id=...
   
   Waiting for authentication...
   ```

3. **Tarayıcınız otomatik açılacak** veya yukarıdaki URL'yi kopyalayıp tarayıcıda açın.

### ✅ Adım 2.3: Google Hesabıyla Giriş Yapın

1. **Tarayıcıda:**
   - Firebase hesabınızla ilişkili Google hesabınızı seçin
   - Şifrenizi girin (gerekirse)

2. **İzin ekranı görünecek:**
   - "Firebase CLI wants to access your Google Account" mesajı
   - **"Allow" (İzin Ver)** butonuna tıklayın

3. **Başarılı mesajı:**
   - "Success! Now using credentials from..." mesajını göreceksiniz
   - Tarayıcıyı kapatabilirsiniz

### ✅ Adım 2.4: Terminal'de Kontrol

Terminal'e geri dönün, şu mesajı görmelisiniz:

```
✔  Success! Logged in as your-email@gmail.com
```

**Başarılı!** Firebase'e giriş yaptınız. Artık deploy edebilirsiniz.

---

## 3. Functions'ı Deploy Etme

### 🚀 Yöntem 1: Deploy Script Kullanarak (Önerilen)

#### Adım 3.1: Script'i Çalıştırılabilir Yapın (İlk kez ise)

```bash
chmod +x deploy_functions.sh
```

#### Adım 3.2: Script'i Çalıştırın

```bash
./deploy_functions.sh
```

**Script şunları yapacak:**
- ✅ Node.js versiyonunu kontrol eder
- ✅ Firebase giriş durumunu kontrol eder
- ✅ Functions bağımlılıklarını kontrol eder
- ✅ Deploy işlemini başlatır

---

### 🚀 Yöntem 2: Manuel Deploy

Eğer script çalışmazsa, manuel olarak şu komutları sırayla çalıştırın:

#### Adım 3.1: NVM'i Yükleyin (Her terminal oturumunda)

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

#### Adım 3.2: Proje Klasöründe Olduğunuzdan Emin Olun

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
pwd  # Bu komut mevcut dizini gösterir, "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR" olmalı
```

#### Adım 3.3: Deploy Komutunu Çalıştırın

```bash
firebase deploy --only functions
```

---

### ⏳ Adım 3.4: Deploy İşlemi

Deploy işlemi sırasında şunları göreceksiniz:

1. **Hazırlık aşaması:**
   ```
   === Deploying to 'sicak-firsatlar-e6eae'...
   
   i  deploying functions
   i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
   ```

2. **Functions derleniyor:**
   ```
   i  functions: preparing codebase for deployment
   i  functions: reading package.json...
   ```

3. **Deploy ediliyor:**
   ```
   ✔  functions[sendDealNotification(us-central1)] Successful create operation.
   ✔  functions[sendDealApprovalNotification(us-central1)] Successful create operation.
   ```

4. **Başarılı:**
   ```
   ✔  Deploy complete!
   
   Project Console: https://console.firebase.google.com/project/sicak-firsatlar-e6eae/overview
   ```

**Tebrikler! 🎉** Functions başarıyla deploy edildi.

---

## 4. Sorun Giderme

### ❌ Sorun 1: "Firebase CLI not found"

**Çözüm:**
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm install -g firebase-tools
```

### ❌ Sorun 2: "Node.js version is incompatible"

**Çözüm:**
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 20
node --version  # v20.x.x olmalı
```

### ❌ Sorun 3: "Permission denied" (Script çalıştırırken)

**Çözüm:**
```bash
chmod +x deploy_functions.sh
./deploy_functions.sh
```

### ❌ Sorun 4: "Failed to list Firebase projects"

**Çözüm:**
Firebase'e yeniden giriş yapın:
```bash
firebase logout
firebase login
```

### ❌ Sorun 5: "Error: Cannot find module"

**Çözüm:**
Functions klasöründe npm install'ı tekrar çalıştırın:
```bash
cd functions
npm install
cd ..
```

---

## 5. Deploy Sonrası Kontrol

### ✅ Firebase Console'da Kontrol Edin

1. Tarayıcıda şu adrese gidin:
   ```
   https://console.firebase.google.com/project/sicak-firsatlar-e6eae/functions
   ```

2. Şu 2 function'ı görmelisiniz:
   - ✅ `sendDealNotification`
   - ✅ `sendDealApprovalNotification`

3. Her ikisi de **"Active"** durumunda olmalı.

### ✅ Test Edin

1. Uygulamada yeni bir deal oluşturun
2. Admin panelinden deal'i onaylayın
3. Bildirimin gönderildiğini kontrol edin

---

## 📝 Hızlı Referans (Copy-Paste Komutları)

### İlk Kurulum (Tek Seferlik)

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 20
firebase login
```

### Deploy İşlemi (Her Deploy'da)

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
./deploy_functions.sh
```

---

## 🎯 Özet

1. ✅ Terminal açın
2. ✅ Proje klasörüne gidin
3. ✅ NVM'i yükleyin: `export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"`
4. ✅ Firebase'e giriş yapın: `firebase login` (tarayıcıda giriş yapın)
5. ✅ Deploy edin: `./deploy_functions.sh`

**İşte bu kadar! 🚀**

Sorularınız varsa lütfen sorun, yardımcı olmaya devam edeceğim.






