# Termux'ta Bot Kurulumu - Basit Rehber

## ✅ Bot artık firebase-admin gerektirmiyor!

Bot kodu güncellendi. Artık hem PC'de hem Termux'ta çalışıyor:
- **PC'de**: firebase-admin kullanır (mevcut kod)
- **Termux'ta**: Firebase REST API kullanır (yeni)

---

## 📱 ADIM 1: Termux'u Hazırlayın

```bash
pkg update && pkg upgrade -y
pkg install python git wget libxml2 libxslt rust libffi clang make cmake libc++ openssl -y
```

---

## 📁 ADIM 2: Bot Klasörünü Oluşturun

```bash
cd ~
mkdir telegram_bot
cd telegram_bot
python -m venv venv
source venv/bin/activate
```

**Kontrol:** Terminal başında `(venv)` yazısı görünmeli.

---

## 📦 ADIM 3: Paketleri Kurun

```bash
pip install --upgrade pip
pip install -r requirements_termux.txt
```

**Not:** `requirements_termux.txt` dosyasını PC'nizden Termux'a kopyalamanız gerekiyor.

---

## 📝 ADIM 4: Dosyaları Oluşturun

### 4.1: `.env` Dosyası

```bash
nano .env
```

İçeriği:
```
TELEGRAM_API_ID=37462587
TELEGRAM_API_HASH=35c8bc7cd010dd61eb5a123e2722be41
TELEGRAM_SESSION_NAME=telegram_session
TELEGRAM_CHANNELS=@indirimkaplani,-3371238729
FIREBASE_CREDENTIALS_PATH=firebase_key.json
```

**Kaydet:** `Ctrl + O` → `Enter` → `Ctrl + X`

### 4.2: `firebase_key.json` Dosyası

```bash
nano firebase_key.json
```

PC'nizdeki `firebase_key.json` dosyasının içeriğini buraya yapıştırın.

**Kaydet:** `Ctrl + O` → `Enter` → `Ctrl + X`

### 4.3: `telegram_bot.py` Dosyası

PC'nizdeki `telegram_bot.py` dosyasını Termux'a kopyalayın.

**Yöntem 1: nano ile oluşturun**
```bash
nano telegram_bot.py
```
PC'deki dosyanın içeriğini kopyalayıp yapıştırın.

**Yöntem 2: USB ile aktarın**
- PC'de dosyayı USB'ye kopyalayın
- Telefona USB'yi bağlayın
- Dosyayı Termux'a kopyalayın

### 4.4: `requirements_termux.txt` Dosyası

PC'nizdeki `requirements_termux.txt` dosyasını Termux'a kopyalayın.

---

## 🚀 ADIM 5: Botu Çalıştırın

```bash
cd ~/telegram_bot
source venv/bin/activate
python telegram_bot.py
```

---

## ⚠️ SORUN GİDERME

### Sorun 1: "No module named 'requests'"
**Çözüm:** `pip install requests`

### Sorun 2: "No module named 'jwt'"
**Çözüm:** `pip install pyjwt`

### Sorun 3: "cryptography" kurulum hatası
**Çözüm:**
```bash
pkg install rust libffi -y
pip install cryptography
```

### Sorun 4: Bot çalışmıyor
**Logları kontrol edin:**
```bash
cat logs/telegram_bot.log
```

---

## ✅ KONTROL LİSTESİ

- [ ] Termux kuruldu
- [ ] Sistem paketleri kuruldu
- [ ] Virtual environment oluşturuldu ve aktif edildi
- [ ] `.env` dosyası oluşturuldu
- [ ] `firebase_key.json` dosyası oluşturuldu
- [ ] `telegram_bot.py` dosyası oluşturuldu
- [ ] `requirements_termux.txt` dosyası oluşturuldu
- [ ] Python paketleri kuruldu
- [ ] Bot çalıştırıldı ve hata yok

---

## 💡 İPUÇLARI

1. **Dosya içeriğini görmek:** `cat dosya_adi`
2. **Klasör içeriğini görmek:** `ls`
3. **Bir klasöre girmek:** `cd klasor_adi`
4. **Virtual environment aktif mi kontrol:** Terminal başında `(venv)` yazısı görünmeli

---

## 🎉 BAŞARILI!

Bot artık Termux'ta çalışıyor ve mobil uygulamanızla entegre! 🚀




