# 📡 Telegram Bot'a Kanal Ekleme (Manuel)

## Adım 1: Oracle Cloud IP Adresini Bul

1. Oracle Cloud paneline git: https://cloud.oracle.com
2. Sol üst menü → **Compute** → **Instances**
3. Bot instance'ını bul ve **Public IP Address**'i kopyala

## Adım 2: Oracle Cloud'a Bağlan

Mac Terminal'inde:

```bash
ssh -i ~/Downloads/ssh-key-2025-11-18.key opc@IP_ADRESI
```

**Not:** Eğer `opc` çalışmazsa `ubuntu` deneyin:
```bash
ssh -i ~/Downloads/ssh-key-2025-11-18.key ubuntu@IP_ADRESI
```

## Adım 3: Bot Dizinine Git

```bash
cd ~/sicak-firsatlar
# veya
cd ~/sicak_firsatlar_bot
```

## Adım 4: .env Dosyasını Düzenle

```bash
nano .env
```

## Adım 5: Kanal Ekle

`.env` dosyasında `TELEGRAM_CHANNELS` veya `SOURCE_CHANNELS` satırını bulun.

**Mevcut kanal varsa:**
```
TELEGRAM_CHANNELS=@mevcut_kanal,@indirimkaplani
```

**Kanal yoksa yeni satır ekleyin:**
```
TELEGRAM_CHANNELS=@indirimkaplani
```

**Kaydet:** `Ctrl+O`, `Enter`, `Ctrl+X`

## Adım 6: Botu Yeniden Başlat

```bash
# Bot'u durdur
pkill -f telegram_bot.py

# Bot'u başlat
source venv/bin/activate
nohup python telegram_bot.py > logs/bot.log 2>&1 &
```

## Adım 7: Kontrol Et

```bash
# Bot çalışıyor mu?
ps aux | grep telegram_bot.py

# Logları izle
tail -f logs/bot.log
```

## ✅ Tamamlandı!

Bot artık `@indirimkaplani` kanalını da dinliyor! 🎉



