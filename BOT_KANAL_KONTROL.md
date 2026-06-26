# 📡 Bot Kanal Kontrol Rehberi

## 🔍 Bot Şu Anda Hangi Kanalları Dinliyor?

Botun dinlediği kanalları kontrol etmek için birkaç yöntem var:

### Yöntem 1: SSH ile Sunucuya Bağlan (Önerilen)

```bash
# SSH key dosyasını hazırla
chmod 400 ~/Downloads/ssh-key-2025-11-18.key

# Sunucuya bağlan
ssh -i ~/Downloads/ssh-key-2025-11-18.key ubuntu@89.168.102.145

# Bot dizinine git
cd ~/sicak-firsatlar
# veya
cd ~/sicak_firsatlar_bot

# .env dosyasını kontrol et
cat .env | grep -E 'TELEGRAM_CHANNELS|SOURCE_CHANNELS'
```

**Beklenen Çıktı:**
```
TELEGRAM_CHANNELS=@indirimkaplani,-3371238729
```
veya
```
SOURCE_CHANNELS=@kanal1,@kanal2
```

### Yöntem 2: Bot Loglarından Kontrol

Bot başladığında loglara şunu yazar:
```
📡 Dinlenen Kanallar: ['@indirimkaplani', '-3371238729']
```

**Logları kontrol et:**
```bash
# SSH ile bağlan
ssh -i ~/Downloads/ssh-key-2025-11-18.key ubuntu@89.168.102.145

# Logları kontrol et
cd ~/sicak-firsatlar
tail -100 logs/bot.log | grep "Dinlenen Kanallar"
# veya
tail -100 bot.log | grep "Dinlenen Kanallar"
```

### Yöntem 3: Bot Process'inden Kontrol

```bash
# SSH ile bağlan
ssh -i ~/Downloads/ssh-key-2025-11-18.key ubuntu@89.168.102.145

# Bot çalışıyor mu kontrol et
ps aux | grep telegram_bot.py

# Eğer çalışıyorsa, logları canlı izle
cd ~/sicak-firsatlar
tail -f logs/bot.log
```

Loglarda şunları göreceksiniz:
- Bot başladığında: `📡 Dinlenen Kanallar: [...]`
- Yeni mesaj geldiğinde: `📩 MESAJ ALINDI: [Kanal ID: ...]`
- Kanal kontrolü: `🔍 Kanal kontrolü: ID=... | Username=@... | Title=...`

### Yöntem 4: check_bot_status.sh Script'i

Proje klasöründe hazır bir script var:

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
bash check_bot_status.sh
```

Bu script otomatik olarak:
- Bot durumunu kontrol eder
- .env dosyasındaki kanalları gösterir
- Son logları gösterir

## 📋 Kanal Formatları

Bot şu formatları destekler:

### 1. Username ile
```
TELEGRAM_CHANNELS=@indirimkaplani
```

### 2. Kanal ID (Negatif - Grup kanalları için)
```
TELEGRAM_CHANNELS=-3371238729
```

### 3. Kanal ID (Pozitif - Özel kanallar için)
```
TELEGRAM_CHANNELS=123456789
```

### 4. Çoklu Kanal (Virgülle ayrılmış)
```
TELEGRAM_CHANNELS=@indirimkaplani,@firsatkanali,-3371238729
```

## ⚠️ SSH Bağlantı Sorunu Varsa

Eğer SSH bağlantısı yapılamıyorsa:

1. **SSH Key Dosyasını Kontrol Et:**
   ```bash
   ls -la ~/Downloads/ssh-key*.key
   ```

2. **Key İzinlerini Kontrol Et:**
   ```bash
   chmod 400 ~/Downloads/ssh-key-2025-11-18.key
   ```

3. **Farklı Kullanıcı Adı Dene:**
   - `ubuntu` yerine `opc` deneyin
   - Veya Oracle Cloud panelinden kullanıcı adını kontrol edin

4. **IP Adresini Kontrol Et:**
   - Oracle Cloud panelinden güncel IP adresini alın
   - IP adresi değişmiş olabilir

5. **Oracle Cloud Console'dan Kontrol:**
   - Oracle Cloud Console'a giriş yapın
   - Compute → Instances → Bot instance'ı seçin
   - Cloud Shell'i açın ve oradan kontrol edin

## 🔧 Hızlı Kontrol Komutu

Tek komutla kontrol etmek için:

```bash
ssh -i ~/Downloads/ssh-key-2025-11-18.key ubuntu@89.168.102.145 \
  "cd ~/sicak-firsatlar 2>/dev/null || cd ~/sicak_firsatlar_bot 2>/dev/null; \
   cat .env 2>/dev/null | grep -E 'TELEGRAM_CHANNELS|SOURCE_CHANNELS' || \
   echo 'Klasör veya .env dosyası bulunamadı'"
```

## 📊 Örnek Çıktılar

### Başarılı Kontrol:
```
TELEGRAM_CHANNELS=@indirimkaplani,-3371238729
```

### Bot Loglarından:
```
2025-01-XX XX:XX:XX - TelegramDealBot - INFO - 📡 Dinlenen Kanallar: ['@indirimkaplani', '-3371238729']
```

### Mesaj İşleme Logları:
```
2025-01-XX XX:XX:XX - TelegramDealBot - INFO - 📩 MESAJ ALINDI: [Kanal ID: -3371238729] - ...
2025-01-XX XX:XX:XX - TelegramDealBot - INFO - 🔍 Kanal kontrolü: ID=-3371238729 | Username=@indirimkaplani | Title=İndirim Kapanı
2025-01-XX XX:XX:XX - TelegramDealBot - INFO - ✅ Hedef kanal bulundu (ID match): -3371238729
```

## 🎯 Sonuç

Botun dinlediği kanalları görmek için:
1. ✅ SSH ile sunucuya bağlan
2. ✅ `.env` dosyasını kontrol et
3. ✅ Veya bot loglarını kontrol et

**Not:** SSH bağlantısı yapılamıyorsa, Oracle Cloud Console'dan Cloud Shell kullanarak kontrol edebilirsiniz.



