# 🔐 Firebase Hesap Değiştirme

## ✅ Durum

- **Şu anda giriş yapılan hesap:** gokayalemdar9@gmail.com
- **Kullanmak istediğiniz hesap:** gokayalendar789@gmail.com

## 🔄 Hesap Değiştirme

### Yöntem 1: Otomatik Script (Önerilen)

Terminal'de şu komutu çalıştırın:

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
./firebase_logout_login.sh
```

Bu script:
1. ✅ Node.js 20'ye geçecek
2. ✅ Mevcut hesaptan çıkış yapacak
3. ✅ Doğru hesap ile giriş yapmanızı sağlayacak
4. ✅ Tarayıcıda **gokayalendar789@gmail.com** ile giriş yapabileceksiniz

---

### Yöntem 2: Manuel Adımlar

Terminal'de şu komutları **sırayla** çalıştırın:

#### 1. Proje klasörüne git
```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
```

#### 2. Node.js 20'ye geç
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 20
```

#### 3. Mevcut hesaptan çıkış
```bash
firebase logout
```

#### 4. Doğru hesap ile giriş
```bash
firebase login
```

Bu komut:
- Tarayıcı açacak
- Google hesap seçim ekranı gelecek
- **gokayalendar789@gmail.com** seçin
- Şifrenizi girin
- "Allow/İzin Ver" butonuna tıklayın

---

## ✅ Kontrol

Giriş yaptıktan sonra, hangi hesap ile giriş yaptığınızı kontrol edin:

```bash
firebase projects:list
```

Bu komut, **gokayalendar789@gmail.com** hesabınızdaki Firebase projelerini listeleyecek.

**Önemli:** `sicak-firsatlar-e6eae` projesinin listede olduğundan emin olun!

---

## 🚀 Deploy

Hesap doğru olduktan sonra:

```bash
./deploy_functions.sh
```

---

## ⚠️ Not

Eğer `gokayalemdar9@gmail.com` hesabı da aynı Firebase projesine erişim yetkisine sahipse, mevcut giriş ile de deploy edebilirsiniz. Ancak doğru hesap ile giriş yapmak daha güvenlidir.






