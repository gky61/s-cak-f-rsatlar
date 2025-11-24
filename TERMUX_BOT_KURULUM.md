# Termux'ta Telegram Bot Kurulum Rehberi

## 📱 ADIM 1: Termux Kurulumu

1. **Termux'u Google Play Store'dan indirin ve kurun**
   - Uygulama adı: "Termux"
   - Yayıncı: Fredrik Fornwall

2. **Termux'u açın ve ilk kurulumu yapın:**
```bash
pkg update && pkg upgrade -y
```

---

## 📦 ADIM 2: Sistem Paketlerini Kurun

Termux'ta şu komutları sırayla çalıştırın:

```bash
# Temel paketler
pkg install python -y
pkg install git -y
pkg install wget -y

# Python bağımlılıkları için gerekli sistem paketleri
pkg install libxml2 libxslt -y
pkg install rust libffi -y
pkg install clang make cmake libc++ -y
pkg install openssl -y
```

---

## 🐍 ADIM 3: Python Virtual Environment Oluşturun

```bash
# Ana dizine gidin
cd ~

# Bot klasörü oluşturun
mkdir telegram_bot
cd telegram_bot

# Python virtual environment oluşturun
python -m venv venv

# Virtual environment'ı aktif edin
source venv/bin/activate
# veya
. venv/bin/activate
```

**Not:** Virtual environment aktif olduğunda terminal başında `(venv)` yazısı görünür.

---

## 📝 ADIM 4: Bot Dosyalarını Oluşturun

Termux'ta şu dosyaları oluşturmanız gerekiyor:

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

**Kaydetmek için:** `Ctrl + O` → `Enter` → `Ctrl + X`

### 4.2: `firebase_key.json` Dosyası

```bash
nano firebase_key.json
```

Firebase key dosyanızın içeriğini buraya yapıştırın.

**Kaydetmek için:** `Ctrl + O` → `Enter` → `Ctrl + X`

### 4.3: `telegram_bot.py` Dosyası

```bash
nano telegram_bot.py
```

Bot kodunuzu buraya yapıştırın.

**Kaydetmek için:** `Ctrl + O` → `Enter` → `Ctrl + X`

### 4.4: `requirements.txt` Dosyası

```bash
nano requirements.txt
```

İçeriği:
```
telethon==1.34.0
firebase-admin==6.5.0
beautifulsoup4==4.12.3
aiohttp==3.9.3
python-dotenv==1.0.1
lxml==5.1.0
```

---

## 🔧 ADIM 5: Python Paketlerini Kurun (ÖNEMLİ)

### 5.1: Önce pip'i güncelleyin

```bash
pip install --upgrade pip
pip install wheel setuptools
```

### 5.2: Paketleri sırayla kurun

**Kolay paketler:**
```bash
pip install python-dotenv==1.0.1
pip install telethon==1.34.0
pip install beautifulsoup4==4.12.3
pip install aiohttp==3.9.3
```

**Zor paketler (sorun yaşarsanız alternatif yöntemler):**

#### lxml Kurulumu:
```bash
# Önce deneyin
pip install lxml==5.1.0

# Eğer hata verirse, önceden derlenmiş versiyonu deneyin
pip install lxml --only-binary :all:

# Hala hata verirse, daha eski versiyon deneyin
pip install lxml==4.9.3
```

#### firebase-admin Kurulumu:

**Yöntem 1: Önceden derlenmiş paketlerle:**
```bash
pip install firebase-admin==6.5.0 --only-binary :all:
```

**Yöntem 2: Eğer yukarıdaki çalışmazsa, daha eski versiyon:**
```bash
pip install firebase-admin==4.5.3
```

**Yöntem 3: En son çare - paketleri ayrı ayrı kurun:**
```bash
# Önce temel paketler
pip install google-auth google-auth-oauthlib google-auth-httplib2
pip install google-api-python-client
pip install google-cloud-firestore google-cloud-storage

# Sonra firebase-admin (daha eski versiyon)
pip install firebase-admin==4.5.3
```

---

## 🚀 ADIM 6: Botu Çalıştırın

### 6.1: Virtual environment'ı aktif edin

```bash
cd ~/telegram_bot
source venv/bin/activate
```

### 6.2: Botu çalıştırın

```bash
python telegram_bot.py
```

---

## ⚠️ SORUN GİDERME

### Sorun 1: "grpcio" kurulum hatası

**Çözüm:**
```bash
# Önce deneyin
pip install grpcio --only-binary :all:

# Çalışmazsa, daha eski versiyon
pip install grpcio==1.48.0
```

### Sorun 2: "cryptography" kurulum hatası

**Çözüm:**
```bash
# Rust ve libffi kurulu olduğundan emin olun
pkg install rust libffi -y

# Sonra cryptography'yi kurun
pip install cryptography
```

### Sorun 3: "lxml" kurulum hatası

**Çözüm:**
```bash
# libxml2 ve libxslt kurulu olduğundan emin olun
pkg install libxml2 libxslt -y

# Sonra lxml'i kurun
pip install lxml --only-binary :all:
```

### Sorun 4: Bot çalışmıyor / Hata veriyor

**Logları kontrol edin:**
```bash
cat logs/telegram_bot.log
```

---

## 📱 ADIM 7: Botu Sürekli Çalıştırma (Opsiyonel)

### Yöntem 1: `nohup` ile arka planda çalıştırma

```bash
cd ~/telegram_bot
source venv/bin/activate
nohup python telegram_bot.py > bot.log 2>&1 &
```

**Botu durdurmak için:**
```bash
pkill -f telegram_bot.py
```

### Yöntem 2: `tmux` ile çalıştırma (Önerilen)

```bash
# tmux kurun
pkg install tmux -y

# Yeni bir tmux session başlatın
tmux new -s bot

# Botu çalıştırın
cd ~/telegram_bot
source venv/bin/activate
python telegram_bot.py

# Session'dan çıkmak için: Ctrl + B, sonra D tuşuna basın
# Session'a geri dönmek için: tmux attach -t bot
```

---

## ✅ KONTROL LİSTESİ

- [ ] Termux kuruldu
- [ ] Sistem paketleri kuruldu (python, git, libxml2, libxslt, rust, libffi, clang, make, cmake)
- [ ] Virtual environment oluşturuldu ve aktif edildi
- [ ] `.env` dosyası oluşturuldu
- [ ] `firebase_key.json` dosyası oluşturuldu
- [ ] `telegram_bot.py` dosyası oluşturuldu
- [ ] `requirements.txt` dosyası oluşturuldu
- [ ] Python paketleri kuruldu (telethon, firebase-admin, beautifulsoup4, aiohttp, python-dotenv, lxml)
- [ ] Bot çalıştırıldı ve hata yok

---

## 📞 YARDIM

Eğer hala sorun yaşıyorsanız:

1. **Hata mesajını tam olarak paylaşın**
2. **Hangi adımda takıldığınızı belirtin**
3. **Termux versiyonunu kontrol edin:** `termux-info`

---

## 💡 İPUÇLARI

- Termux'ta dosya düzenlemek için `nano` editörünü kullanabilirsiniz
- Dosya içeriğini görmek için `cat dosya_adi` komutunu kullanın
- Klasör içeriğini görmek için `ls` komutunu kullanın
- Bir klasöre girmek için `cd klasor_adi` komutunu kullanın
- Bir üst klasöre çıkmak için `cd ..` komutunu kullanın




