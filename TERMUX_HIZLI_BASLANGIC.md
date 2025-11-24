# Termux Hızlı Başlangıç - En Basit Yöntem

## 🎯 HEDEF: Botu Termux'ta çalıştırmak

---

## 📱 ADIM 1: Termux'u Hazırlayın

Termux'u açın ve şu komutları **sırayla** çalıştırın:

```bash
# 1. Paketleri güncelle
pkg update && pkg upgrade -y

# 2. Temel paketleri kur
pkg install python git wget -y

# 3. Python bağımlılıkları için gerekli paketler
pkg install libxml2 libxslt rust libffi clang make cmake libc++ openssl -y
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

**Not:** `(venv)` yazısı görünüyorsa başarılı!

---

## 📝 ADIM 3: Dosyaları Oluşturun

### 3.1: `.env` Dosyası

```bash
nano .env
```

**İçeriği yapıştırın:**
```
TELEGRAM_API_ID=37462587
TELEGRAM_API_HASH=35c8bc7cd010dd61eb5a123e2722be41
TELEGRAM_SESSION_NAME=telegram_session
TELEGRAM_CHANNELS=@indirimkaplani,-3371238729
FIREBASE_CREDENTIALS_PATH=firebase_key.json
```

**Kaydet:** `Ctrl + O` → `Enter` → `Ctrl + X`

### 3.2: `firebase_key.json` Dosyası

```bash
nano firebase_key.json
```

Firebase key dosyanızın içeriğini yapıştırın.

**Kaydet:** `Ctrl + O` → `Enter` → `Ctrl + X`

### 3.3: `telegram_bot.py` Dosyası

PC'nizdeki `telegram_bot.py` dosyasını Termux'a aktarmanız gerekiyor.

**Yöntem 1: Termux'ta doğrudan oluşturun**
```bash
nano telegram_bot.py
```
PC'nizdeki dosyanın içeriğini kopyalayıp yapıştırın.

**Yöntem 2: USB ile aktarın**
- PC'de dosyayı USB'ye kopyalayın
- Telefona USB'yi bağlayın
- Dosyayı Termux'a kopyalayın

**Yöntem 3: GitHub kullanın (en kolay)**
```bash
# GitHub'a yükleyin, sonra Termux'ta:
git clone https://github.com/kullanici_adi/repo_adi.git
cd repo_adi
# Dosyaları telegram_bot klasörüne kopyalayın
```

---

## 🔧 ADIM 4: Paketleri Kurun (Basit Yöntem)

```bash
# pip'i güncelle
pip install --upgrade pip

# Kolay paketler
pip install python-dotenv telethon beautifulsoup4 aiohttp

# Zor paketler - önce önceden derlenmiş versiyonları deneyin
pip install lxml --only-binary :all:
pip install firebase-admin --only-binary :all:

# Eğer yukarıdaki çalışmazsa, eski versiyonları deneyin
pip install lxml==4.9.3
pip install firebase-admin==4.5.3
```

---

## 🚀 ADIM 5: Botu Çalıştırın

```bash
cd ~/telegram_bot
source venv/bin/activate
python telegram_bot.py
```

---

## ⚠️ HATA ALIRSANIZ

### Hata: "No module named 'telethon'"
**Çözüm:** `pip install telethon` çalıştırın

### Hata: "lxml" kurulamıyor
**Çözüm:** 
```bash
pkg install libxml2 libxslt -y
pip install lxml==4.9.3
```

### Hata: "firebase-admin" kurulamıyor
**Çözüm:**
```bash
pip install firebase-admin==4.5.3
```

### Hata: "grpcio" kurulamıyor
**Çözüm:**
```bash
pip install grpcio==1.48.0
```

---

## 💡 İPUÇLARI

1. **Dosya içeriğini görmek:** `cat dosya_adi`
2. **Klasör içeriğini görmek:** `ls`
3. **Bir klasöre girmek:** `cd klasor_adi`
4. **Bir üst klasöre çıkmak:** `cd ..`
5. **Virtual environment aktif mi kontrol:** Terminal başında `(venv)` yazısı görünmeli

---

## 📞 YARDIM

Hangi adımda takıldınız? Hata mesajını paylaşın, birlikte çözelim!




