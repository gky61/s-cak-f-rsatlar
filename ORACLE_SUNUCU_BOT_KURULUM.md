# 🚀 Oracle Sunucuya Bot Kurulum Rehberi

## 📋 Gereksinimler

✅ SSH Key dosyası bulundu: `ssh-key-2025-11-18.key`  
✅ Dosya konumu: `/Users/gokayalemdar/Downloads/ssh-key-2025-11-18.key`

## 🔑 ADIM 1: SSH Key Dosyasını Hazırla

Mac Terminal'inde şu komutu çalıştır:

```bash
chmod 400 ~/Downloads/ssh-key-2025-11-18.key
```

Bu komut dosyaya sadece senin okuma izni verir (güvenlik için gerekli).

## 🌐 ADIM 2: Oracle Sunucu IP Adresini Bul

1. Oracle Cloud paneline git: https://cloud.oracle.com
2. Sol üst menü → **Compute** → **Instances**
3. `telegram-bot` (veya benzer isimli) instance'ı bul
4. Tıkla ve **Public IP Address**'i kopyala
   - Örnek: `140.238.123.45`

**Not:** IP adresini bir yere not al, her adımda kullanacağız.

## 🔌 ADIM 3: Sunucuya Bağlan (SSH)

Mac Terminal'inde:

```bash
ssh -i ~/Downloads/ssh-key-2025-11-18.key opc@IP_ADRESI
```

**Örnek:**
```bash
ssh -i ~/Downloads/ssh-key-2025-11-18.key opc@140.238.123.45
```

**İlk bağlantıda şu mesajı görebilirsin:**
```
The authenticity of host '...' can't be established.
Are you sure you want to continue connecting (yes/no)?
```
**`yes` yaz ve Enter'a bas.**

Başarılı olursa şöyle bir prompt göreceksin:
```bash
[opc@instance-2025-xxxx ~]$
```

**Artık sunucunun içindesin! 🎉**

## 🛠️ ADIM 4: Sunucuda Ortamı Hazırla

Sunucu terminalinde (SSH bağlantısı açıkken) şu komutları sırayla çalıştır:

```bash
# 1. Sistemi güncelle ve Python kur
sudo yum update -y
sudo yum install -y python3 python3-pip git

# 2. Proje klasörünü oluştur
mkdir -p ~/sicak-firsatlar
cd ~/sicak-firsatlar

# 3. Virtual environment oluştur
python3 -m venv venv
source venv/bin/activate

# Prompt'ta (venv) görünmeli
```

**Bu terminali açık bırak** (çıkmak istersen `exit` yazabilirsin, sonra tekrar bağlanırsın).

## 📤 ADIM 5: Dosyaları Mac'ten Sunucuya Gönder

**YENİ bir Terminal penceresi aç** (Mac'te, sunucuya bağlı değil).

Mac Terminal'inde:

```bash
# Proje klasörüne git
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"

# IP_ADRESI yerine gerçek IP'yi yaz!
IP_ADRESI="140.238.123.45"  # ÖRNEK - Sen kendi IP'ni yaz

# Bot dosyasını gönder
scp -i ~/Downloads/ssh-key-2025-11-18.key telegram_bot.py opc@$IP_ADRESI:~/sicak-firsatlar/

# Gereksinimler dosyasını gönder
scp -i ~/Downloads/ssh-key-2025-11-18.key requirements.txt opc@$IP_ADRESI:~/sicak-firsatlar/

# ÇOK ÖNEMLİ: .env dosyasını gönder
scp -i ~/Downloads/ssh-key-2025-11-18.key .env opc@$IP_ADRESI:~/sicak-firsatlar/

# ÇOK ÖNEMLİ: Firebase key dosyasını gönder
scp -i ~/Downloads/ssh-key-2025-11-18.key firebase_key.json opc@$IP_ADRESI:~/sicak-firsatlar/
```

**Her komut başarılı olursa hiçbir hata mesajı görmemelisin.**

## 📦 ADIM 6: Sunucuda Bağımlılıkları Yükle ve Botu Çalıştır

**Sunucu terminaline geri dön** (SSH bağlantısı açık olan).

```bash
# Klasöre git
cd ~/sicak-firsatlar

# Virtual environment'ı aktif et
source venv/bin/activate

# Bağımlılıkları yükle
pip install --upgrade pip
pip install -r requirements.txt

# Bu işlem birkaç dakika sürebilir...
```

## 🚀 ADIM 7: Botu Başlat

### Test Amaçlı (Önce Bunu Dene):

```bash
python telegram_bot.py
```

**Şu mesajları görmelisin:**
- ✅ Telegram Client başlatıldı
- 🔄 Kanallardan mesajlar çekiliyor...
- ✅ Deal Firebase'e kaydedildi: ...

**Eğer çalışıyorsa:** `Ctrl+C` ile durdur ve bir sonraki adıma geç.

### Sürekli Çalıştırma (7/24):

```bash
# Arka planda çalıştır
nohup python telegram_bot.py > bot.log 2>&1 &

# Bot'un çalıştığını kontrol et
ps aux | grep telegram_bot.py

# Logları izle
tail -f bot.log
```

**Artık bot Oracle sunucuda 7/24 çalışıyor! 🎉**

## 🔍 Bot Durumunu Kontrol Etme

### Bot çalışıyor mu?
```bash
ps aux | grep telegram_bot.py
```

### Logları görüntüle:
```bash
tail -f ~/sicak-firsatlar/bot.log
```

### Bot'u durdur:
```bash
pkill -f telegram_bot.py
```

### Bot'u yeniden başlat:
```bash
cd ~/sicak-firsatlar
source venv/bin/activate
nohup python telegram_bot.py > bot.log 2>&1 &
```

## 📝 Hızlı Başlatma Script'i (İsteğe Bağlı)

Sunucuda `~/sicak-firsatlar/start_bot.sh` dosyası oluştur:

```bash
cd ~/sicak-firsatlar
cat > start_bot.sh << 'EOF'
#!/bin/bash
cd ~/sicak-firsatlar
source venv/bin/activate
nohup python telegram_bot.py > bot.log 2>&1 &
echo "Bot başlatıldı! Logları görmek için: tail -f bot.log"
EOF

chmod +x start_bot.sh
```

**Kullanım:**
```bash
~/sicak-firsatlar/start_bot.sh
```

## ⚠️ Sorun Giderme

### SSH bağlantı hatası:
- IP adresini kontrol et
- Key dosyasının izinlerini kontrol et: `chmod 400 ~/Downloads/ssh-key-2025-11-18.key`
- Oracle Security List'te port 22 açık mı kontrol et

### Dosya gönderme hatası:
- IP adresini doğru yazdığından emin ol
- Key dosyasının yolunu kontrol et
- `.env` ve `firebase_key.json` dosyalarının var olduğundan emin ol

### Bot çalışmıyor:
- Logları kontrol et: `tail -f bot.log`
- Virtual environment aktif mi: `which python` → `venv/bin/python` görünmeli
- Bağımlılıklar yüklü mü: `pip list | grep telethon`

## ✅ Başarı Kriterleri

1. ✅ SSH ile sunucuya bağlanabiliyorsun
2. ✅ Dosyalar sunucuya kopyalandı
3. ✅ Bot çalışıyor ve log yazıyor
4. ✅ Firebase'e deal'ler kaydediliyor

## 📞 Yardım

Sorun yaşarsan:
- SSH bağlantı loglarını paylaş
- Bot loglarını paylaş: `cat ~/sicak-firsatlar/bot.log`
- Hata mesajlarını paylaş


