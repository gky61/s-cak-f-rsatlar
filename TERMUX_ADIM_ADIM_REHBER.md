# Termux'ta Bot Kurulumu - Sıfırdan Başlayanlar İçin Rehber

Bu rehber, Termux'u hiç bilmeyen biri için hazırlanmıştır. Her adım detaylıca açıklanmıştır.

---

## 📱 BÖLÜM 1: Termux Nedir ve Nasıl Kurulur?

### Termux Nedir?
Termux, Android telefonunuzda Linux komutlarını çalıştırmanızı sağlayan bir uygulamadır. Bilgisayarınızdaki terminal (komut satırı) gibi çalışır.

### Termux'u Nasıl Kurarım?

1. **Google Play Store'u açın**
   - Telefonunuzda Play Store uygulamasını açın

2. **"Termux" yazın ve arayın**
   - Arama çubuğuna "Termux" yazın
   - İlk sonuçta "Termux" uygulamasını bulun
   - Yayıncı: Fredrik Fornwall

3. **Kurulum butonuna tıklayın**
   - "Yükle" veya "Install" butonuna tıklayın
   - Kurulum tamamlanana kadar bekleyin

4. **Termux'u açın**
   - Kurulum tamamlandıktan sonra "Aç" veya "Open" butonuna tıklayın
   - Veya uygulama menüsünden Termux'u açın

---

## 🎯 BÖLÜM 2: Termux İlk Açılış

Termux'u ilk açtığınızda siyah bir ekran göreceksiniz. Bu normaldir. Bu ekranda komutlar yazacaksınız.

### Termux Ekranı Nasıl Görünür?

```
$ 
```

Bu `$` işareti, komut yazmaya hazır olduğunuzu gösterir.

### İlk Komutlar

Termux'u açtıktan sonra şu komutları **sırayla** yazın (her komuttan sonra Enter'a basın):

```bash
pkg update
```

**Ne yapar?** Termux'un paket listesini günceller.

**Beklenen sonuç:** Bir süre bekleyecek, sonra tekrar `$` işareti görünecek.

```bash
pkg upgrade -y
```

**Ne yapar?** Termux'u en son versiyona günceller.

**Beklenen sonuç:** Bir süre bekleyecek, sonra tekrar `$` işareti görünecek.

---

## 📦 BÖLÜM 3: Gerekli Paketleri Kurma

Bot'u çalıştırmak için bazı paketlerin kurulu olması gerekir. Şu komutları **sırayla** yazın:

### Adım 1: Temel Paketler

**ÖNEMLİ:** Önce paket listesini güncelleyin:

```bash
pkg update
```

**Beklenen sonuç:** Bir süre bekleyecek, sonra tekrar `$` işareti görünecek.

**Eğer hata alırsanız:** Termux'un paket deposu sorunlu olabilir. Şunu deneyin:

```bash
termux-change-repo
```

Bu komut çalıştığında:
1. "Select a mirror" seçeneğini seçin
2. Farklı bir mirror (ayna) seçin (örn: "Mirror by Grimler")
3. "OK" tuşuna basın
4. Tekrar `pkg update` çalıştırın

Şimdi Python'u kurun:

```bash
pkg install python -y
```

**Ne yapar?** Python programlama dilini kurar.

**Beklenen sonuç:** "Do you want to continue? [Y/n]" gibi bir soru sorabilir. `Y` yazıp Enter'a basın.

**Not 1:** Eğer "unable to locate package python" hatası alırsanız, şunu deneyin:
```bash
pkg install python3 -y
```

**Not 2:** Eğer hala hata alırsanız, şunu deneyin:
```bash
apt update && apt install python -y
```

**Not 3:** Eğer hiçbiri çalışmazsa, Termux'u silip yeniden kurun veya Termux'un en son versiyonunu kullandığınızdan emin olun.

```bash
pkg install git -y
```

**Ne yapar?** Git versiyon kontrol sistemini kurar.

```bash
pkg install wget -y
```

**Ne yapar?** Dosya indirme aracını kurar.

### Adım 2: Python Bağımlılıkları İçin Gerekli Paketler

```bash
pkg install libxml2 libxslt -y
```

**Ne yapar?** XML işleme kütüphanelerini kurar.

```bash
pkg install rust libffi -y
```

**Ne yapar?** Rust ve libffi kütüphanelerini kurar (bazı Python paketleri için gerekli).

```bash
pkg install clang make cmake libc++ -y
```

**Ne yapar?** Derleyici araçlarını kurar.

```bash
pkg install openssl -y
```

**Ne yapar?** SSL/TLS kütüphanesini kurar.

**Önemli:** Her komut birkaç dakika sürebilir. Sabırla bekleyin.

---

## 📁 BÖLÜM 4: Bot Klasörü Oluşturma

### Adım 1: Ana Dizine Gitmek

Termux'ta şu komutu yazın:

```bash
cd ~
```

**Ne yapar?** Ana dizine (home directory) gider.

**Beklenen sonuç:** `$` işareti görünür, değişiklik olmaz (zaten ana dizindesiniz).

### Adım 2: Bot Klasörü Oluşturmak

```bash
mkdir telegram_bot
```

**Ne yapar?** "telegram_bot" adında bir klasör oluşturur.

**Beklenen sonuç:** Hata mesajı görünmezse başarılıdır.

### Adım 3: Klasöre Girmek

```bash
cd telegram_bot
```

**Ne yapar?** Oluşturduğunuz klasöre girer.

**Beklenen sonuç:** Terminal satırının başında `~/telegram_bot $` görünür.

### Adım 4: Python Virtual Environment Oluşturmak

```bash
python -m venv venv
```

**Ne yapar?** Python için izole bir ortam oluşturur.

**Beklenen sonuç:** Birkaç saniye bekler, sonra `$` işareti görünür.

### Adım 5: Virtual Environment'ı Aktif Etmek

```bash
source venv/bin/activate
```

**Ne yapar?** Oluşturduğunuz Python ortamını aktif eder.

**Beklenen sonuç:** Terminal satırının başında `(venv)` yazısı görünür:
```
(venv) ~/telegram_bot $
```

**Önemli:** `(venv)` yazısı görünmüyorsa, komutu tekrar yazın veya `bash venv/bin/activate` deneyin.

---

## 📝 BÖLÜM 5: Dosyaları Oluşturma

Bot'u çalıştırmak için 4 dosya oluşturmanız gerekir:
1. `.env` - Bot ayarları
2. `firebase_key.json` - Firebase anahtarı
3. `telegram_bot.py` - Bot kodu
4. `requirements_termux.txt` - Paket listesi

### Dosya Oluşturma: nano Editörü

Termux'ta dosya oluşturmak için `nano` editörünü kullanacağız.

**nano Editörü Nasıl Kullanılır?**
- Dosyayı açmak: `nano dosya_adi`
- Yazmak: Normal yazı yazabilirsiniz
- Kaydetmek: `Ctrl + O` tuşlarına basın, sonra `Enter`
- Çıkmak: `Ctrl + X` tuşlarına basın

**Önemli:** Termux'ta `Ctrl` tuşu için klavyenizdeki `Ctrl` tuşunu kullanın. Bazı telefonlarda `Volume Down + Q` kombinasyonu da çalışabilir.

---

### Dosya 1: `.env` Dosyası

#### Adım 1: Dosyayı Oluşturun

```bash
nano .env
```

**Ne yapar?** `.env` adında bir dosya oluşturur ve nano editörünü açar.

**Beklenen sonuç:** Ekranın altında "New File" yazısı görünür.

#### Adım 2: İçeriği Yazın

Aşağıdaki metni **tam olarak** kopyalayıp Termux'a yapıştırın:

```
TELEGRAM_API_ID=37462587
TELEGRAM_API_HASH=35c8bc7cd010dd61eb5a123e2722be41
TELEGRAM_SESSION_NAME=telegram_session
TELEGRAM_CHANNELS=@indirimkaplani,-3371238729
FIREBASE_CREDENTIALS_PATH=firebase_key.json
```

**Yapıştırma:** Termux'ta uzun basın → "Paste" seçeneğine tıklayın.

#### Adım 3: Dosyayı Kaydedin

1. `Ctrl + O` tuşlarına basın
2. `Enter` tuşuna basın
3. `Ctrl + X` tuşlarına basın

**Beklenen sonuç:** Tekrar `(venv) ~/telegram_bot $` görünür.

---

### Dosya 2: `firebase_key.json` Dosyası

#### Adım 1: Dosyayı Oluşturun

```bash
nano firebase_key.json
```

#### Adım 2: İçeriği Yazın

PC'nizdeki `firebase_key.json` dosyasının içeriğini kopyalayıp Termux'a yapıştırın.

**PC'den İçeriği Kopyalama:**
1. PC'nizde `firebase_key.json` dosyasını açın
2. Tüm içeriği seçin (`Ctrl + A`)
3. Kopyalayın (`Ctrl + C`)

**Termux'a Yapıştırma:**
1. Termux'ta uzun basın
2. "Paste" seçeneğine tıklayın

#### Adım 3: Dosyayı Kaydedin

1. `Ctrl + O` → `Enter` → `Ctrl + X`

---

### Dosya 3: `telegram_bot.py` Dosyası

Bu dosya çok uzun olduğu için PC'nizden kopyalamanız daha kolay olacaktır.

#### Yöntem 1: nano ile Oluşturma (Uzun)

```bash
nano telegram_bot.py
```

PC'nizdeki `telegram_bot.py` dosyasının tüm içeriğini kopyalayıp yapıştırın.

#### Yöntem 2: USB ile Aktarma (Önerilen)

1. **PC'de:**
   - `telegram_bot.py` dosyasını USB belleğe kopyalayın
   - Veya dosyayı telefonunuza e-posta ile gönderin

2. **Telefonda:**
   - Dosyayı indirin
   - Dosya yöneticisinde bulun

3. **Termux'ta:**
   ```bash
   # Dosyayı Termux'a kopyalayın
   cp /sdcard/Download/telegram_bot.py ~/telegram_bot/
   ```
   
   **Not:** Dosya yolu farklı olabilir. Dosya yöneticisinde dosyanın tam yolunu bulun.

#### Yöntem 3: GitHub Kullanma (En Kolay)

1. **PC'de:**
   - `telegram_bot.py` dosyasını GitHub'a yükleyin

2. **Termux'ta:**
   ```bash
   wget https://raw.githubusercontent.com/kullanici_adi/repo_adi/main/telegram_bot.py
   ```

---

### Dosya 4: `requirements_termux.txt` Dosyası

```bash
nano requirements_termux.txt
```

Aşağıdaki içeriği yapıştırın:

```
telethon==1.34.0
beautifulsoup4==4.12.3
aiohttp==3.9.3
python-dotenv==1.0.1
pyjwt==2.8.0
cryptography==41.0.7
requests==2.31.0
```

Kaydedin: `Ctrl + O` → `Enter` → `Ctrl + X`

---

## 🔧 BÖLÜM 6: Python Paketlerini Kurma

### Adım 1: pip'i Güncelleyin

```bash
pip install --upgrade pip
```

**Ne yapar?** Python paket yöneticisini günceller.

**Beklenen sonuç:** Birkaç saniye bekler, sonra "Successfully installed pip..." gibi bir mesaj görünür.

### Adım 2: Paketleri Kurun

```bash
pip install -r requirements_termux.txt
```

**Ne yapar?** `requirements_termux.txt` dosyasındaki tüm paketleri kurar.

**Beklenen sonuç:** 
- Birkaç dakika sürebilir
- "Successfully installed..." mesajları görünür
- Hata mesajı görünmezse başarılıdır

**Önemli:** Eğer hata görürseniz, hata mesajını not edin ve yardım isteyin.

---

## 🚀 BÖLÜM 7: Botu Çalıştırma

### Adım 1: Klasöre Gidin

```bash
cd ~/telegram_bot
```

### Adım 2: Virtual Environment'ı Aktif Edin

```bash
source venv/bin/activate
```

**Kontrol:** Terminal başında `(venv)` yazısı görünmeli.

### Adım 3: Botu Çalıştırın

```bash
python telegram_bot.py
```

**Beklenen sonuç:**
- Bot başlar
- "✅ Firebase başlatıldı (REST API...)" gibi mesajlar görünür
- "✅ Telegram Client başlatıldı" mesajı görünür
- Bot çalışmaya başlar

**Botu Durdurmak:** `Ctrl + C` tuşlarına basın.

---

## ⚠️ SORUN GİDERME

### Sorun 1: "command not found: pkg"

**Çözüm:** Termux düzgün kurulmamış. Termux'u silip yeniden kurun.

### Sorun 2: "No module named 'telethon'"

**Çözüm:** Paketler kurulmamış. Şu komutu çalıştırın:
```bash
pip install telethon
```

### Sorun 3: "Permission denied"

**Çözüm:** Virtual environment aktif değil. Şu komutu çalıştırın:
```bash
source venv/bin/activate
```

### Sorun 4: Dosya bulunamadı

**Çözüm:** Doğru klasörde olduğunuzdan emin olun:
```bash
cd ~/telegram_bot
ls
```
`ls` komutu klasördeki dosyaları listeler. Gerekli dosyalar görünmeli.

### Sorun 5: nano'da kaydedemiyorum

**Çözüm:** 
- `Ctrl + O` tuşlarına basın
- `Enter` tuşuna basın
- `Ctrl + X` tuşlarına basın

Bazı telefonlarda `Volume Down + Q` kombinasyonu da çalışabilir.

---

## 📱 BÖLÜM 8: Botu Sürekli Çalıştırma

Bot'u kapatmadan sürekli çalıştırmak istiyorsanız:

### Yöntem 1: nohup Kullanma

```bash
nohup python telegram_bot.py > bot.log 2>&1 &
```

**Ne yapar?** Bot'u arka planda çalıştırır.

**Botu Durdurmak:**
```bash
pkill -f telegram_bot.py
```

### Yöntem 2: tmux Kullanma (Önerilen)

```bash
# tmux kurun
pkg install tmux -y

# Yeni bir session başlatın
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

Kurulumu tamamladığınızda şunlar olmalı:

- [ ] Termux kuruldu ve açıldı
- [ ] `pkg update && pkg upgrade -y` çalıştırıldı
- [ ] Tüm sistem paketleri kuruldu (python, git, wget, libxml2, libxslt, rust, libffi, clang, make, cmake, libc++, openssl)
- [ ] `telegram_bot` klasörü oluşturuldu
- [ ] Virtual environment oluşturuldu (`python -m venv venv`)
- [ ] Virtual environment aktif edildi (`(venv)` görünüyor)
- [ ] `.env` dosyası oluşturuldu
- [ ] `firebase_key.json` dosyası oluşturuldu
- [ ] `telegram_bot.py` dosyası oluşturuldu
- [ ] `requirements_termux.txt` dosyası oluşturuldu
- [ ] `pip install -r requirements_termux.txt` çalıştırıldı (hata yok)
- [ ] `python telegram_bot.py` çalıştırıldı (bot başladı)

---

## 💡 İPUÇLARI

1. **Komutları kopyalama:** Termux'ta uzun basın → "Paste" seçeneğine tıklayın
2. **Dosya içeriğini görmek:** `cat dosya_adi` komutunu kullanın
3. **Klasör içeriğini görmek:** `ls` komutunu kullanın
4. **Bir klasöre girmek:** `cd klasor_adi` komutunu kullanın
5. **Bir üst klasöre çıkmak:** `cd ..` komutunu kullanın
6. **Virtual environment aktif mi kontrol:** Terminal başında `(venv)` yazısı görünmeli

---

## 📞 YARDIM

Eğer hala sorun yaşıyorsanız:

1. **Hata mesajını tam olarak paylaşın**
2. **Hangi adımda takıldığınızı belirtin**
3. **Termux versiyonunu kontrol edin:** `termux-info` komutunu çalıştırın

---

## 🎉 BAŞARILI!

Kurulum tamamlandıysa, bot artık Termux'ta çalışıyor ve mobil uygulamanızla entegre! 🚀

