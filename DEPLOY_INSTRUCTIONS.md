# Firebase Functions Deploy Talimatları

## ✅ Tamamlanan İşlemler

1. ✅ Node.js v20.19.5 yüklendi
2. ✅ Functions klasöründe `npm install` başarıyla tamamlandı

## 🔐 Firebase'e Giriş Yapma

Terminal'de şu komutu çalıştırın:

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
firebase login
```

Bu komut sizi tarayıcıda açılacak bir sayfaya yönlendirecek. Firebase hesabınızla giriş yapın.

## 🚀 Functions'ı Deploy Etme

Giriş yaptıktan sonra şu komutu çalıştırın:

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
firebase deploy --only functions
```

## 📝 Notlar

- Firebase proje ID'si: `sicak-firsatlar-e6eae` (zaten yapılandırılmış)
- Functions klasöründeki tüm bağımlılıklar yüklenmiş durumda
- Deploy işlemi 2-5 dakika sürebilir

## ✅ Deploy Başarılı Olduğunda

Deploy başarılı olduğunda:
- Firestore'da yeni deal oluşturulduğunda otomatik bildirim gönderilecek
- Deal onaylandığında otomatik bildirim gönderilecek
- Bildirimler kategori ve alt kategori topic'lerine gönderilecek

## 🔍 Deploy Durumunu Kontrol Etme

Firebase Console'dan kontrol edebilirsiniz:
- https://console.firebase.google.com/project/sicak-firsatlar-e6eae/functions






