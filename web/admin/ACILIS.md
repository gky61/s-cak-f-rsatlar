# 🌐 Web Admin Paneli Nasıl Açılır?

## 🚀 Canlı Versiyon (Önerilen)

1. **Tarayıcınızı açın** (Chrome, Safari, Firefox, vb.)

2. **Adres çubuğuna şu URL'yi yazın:**
   ```
   https://sicak-firsatlar-e6eae.web.app/admin/
   ```
   ⚠️ **ÖNEMLİ:** Sonunda mutlaka `/admin/` olmalı!

3. **Enter'a basın**

4. **Google ile Giriş Yap** butonuna tıklayın

5. **Admin yetkisine sahip Google hesabınızla giriş yapın**

6. **Admin paneli açılacak!** 🎉

---

## 💻 Yerel Test (Geliştirme İçin)

Eğer kod değişikliği yapıp test etmek istiyorsanız:

### Seçenek 1: Python ile
```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR/web/admin"
python3 -m http.server 8000
```
Sonra tarayıcıda: `http://localhost:8000`

### Seçenek 2: Firebase Serve ile
```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
firebase serve --only hosting
```
Sonra tarayıcıda: `http://localhost:5000/admin`

---

## 🔐 Giriş Sorunları

**"Bu hesap admin yetkisine sahip değil" hatası alıyorsanız:**

1. Firebase Console'a gidin: https://console.firebase.google.com/project/sicak-firsatlar-e6eae
2. Firestore Database > `users` koleksiyonuna gidin
3. Kullanıcı ID'nizi bulun (veya yeni bir doküman oluşturun)
4. `isAdmin: true` alanını ekleyin

---

## 📱 Mobil Uyumlu

Web admin paneli mobil cihazlarda da çalışır, ancak PC'de kullanım daha rahattır.

---

## 🆘 Sorun mu var?

- **Sayfa açılmıyor:** Hard refresh yapın (Cmd+Shift+R veya Ctrl+Shift+R)
- **Giriş yapamıyorum:** Admin yetkisini kontrol edin
- **Hiçbir şey görünmüyor:** Tarayıcı konsolunu açın (F12) ve hataları kontrol edin





