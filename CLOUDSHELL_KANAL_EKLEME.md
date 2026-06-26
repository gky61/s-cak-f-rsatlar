# 📡 Oracle Cloud Shell'den Kanal Ekleme

Oracle Cloud Shell'de şu komutları sırayla çalıştırın:

## 1. Bot Sunucusunun IP Adresini Bul

```bash
# Compute instance'ları listele
oci compute instance list --compartment-id $(oci iam compartment list --all --query "data[?name=='root'].id | [0]" --raw-output) --query "data[*].{Name:display-name,PublicIP:\"public-ip\",State:lifecycle-state}" --output table
```

Veya daha basit:

```bash
# Tüm instance'ları listele
oci compute instance list --all --query "data[*].{Name:display-name,OCID:id}" --output table
```

## 2. Bot Sunucusuna Bağlan

IP adresini bulduktan sonra:

```bash
# opc kullanıcısı ile dene
ssh opc@IP_ADRESI

# veya ubuntu kullanıcısı ile
ssh ubuntu@IP_ADRESI
```

## 3. Bot Dizinine Git

```bash
cd ~/sicak-firsatlar
# veya
cd ~/sicak_firsatlar_bot
```

## 4. Mevcut Kanalları Kontrol Et

```bash
cat .env | grep TELEGRAM_CHANNELS
```

## 5. Kanal Ekle

```bash
# .env dosyasını düzenle
nano .env
```

`TELEGRAM_CHANNELS` satırını bulun ve `@indirimkaplani` ekleyin:

**Mevcut kanal varsa:**
```
TELEGRAM_CHANNELS=@mevcut_kanal,@indirimkaplani
```

**Kanal yoksa:**
```
TELEGRAM_CHANNELS=@indirimkaplani
```

Kaydet: `Ctrl+O`, `Enter`, `Ctrl+X`

## 6. Botu Yeniden Başlat

```bash
# Bot'u durdur
pkill -f telegram_bot.py

# Bot'u başlat
source venv/bin/activate
nohup python telegram_bot.py > logs/bot.log 2>&1 &
```

## 7. Kontrol Et

```bash
# Bot çalışıyor mu?
ps aux | grep telegram_bot.py

# Logları izle
tail -f logs/bot.log
```

## ✅ Tamamlandı!

Bot artık `@indirimkaplani` kanalını da dinliyor! 🎉



