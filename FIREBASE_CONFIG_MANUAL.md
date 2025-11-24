# 🔧 Firebase Config Manuel Ayarlama

Node.js versiyonu düşük olduğu için Firebase CLI çalışmıyor. İki seçeneğiniz var:

## Seçenek 1: Node.js'i Güncelleyin (Önerilen)

### macOS için:

```bash
# Homebrew ile
brew install node@20

# veya nvm ile
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.zshrc
nvm install 20
nvm use 20
```

Sonra tekrar deneyin:
```bash
firebase functions:config:set telegram.api_id="37462587"
firebase functions:config:set telegram.api_hash="35c8bc7cd010dd61eb5a123e2722be41"
firebase functions:config:set telegram.session_string="1BAAOMTQ5LjE1NC4xNjcuOTEAUH1G1uC4mMdqGaXNOcR065VVmuGzwx+XcMAriyt1/m2H0GjGlcxiOPQ1a84arWKw3s7u5SwFKYRDwDSDTFz5r0pNUcYKAxQ/WwPJ9cJ2NaiVVWYjlkJ06nPzL1V6gC5XOn4+7Qvx2c1eeIggi4UmgpS5n1HyTWVYF0SxnM9o9fSR+KolzCxy8154MAG4GnBUG18LGSjLr6/MvB9FDpf+/uWsIy24h6Pj4SPad9Vd1FJGycla9ZKTXA5ipKWrjJmBLOzycAY43VSl5xVFBO5MDdlAgb+QtPTR3WfF6HX+CeFmWPAyOgpaZz1l094XAk6NPMpxxX2OrXztpi6pUoVWQeg="
firebase functions:config:set telegram.channel_username="@donanimhabersicakfirsatlar"
```

## Seçenek 2: Firebase Console'dan Ayarlayın

1. Firebase Console'a gidin: https://console.firebase.google.com
2. Projenizi seçin: `sicak-firsatlar-e6eae`
3. Sol menüden **Functions** > **Config** bölümüne gidin
4. Şu değişkenleri ekleyin:

```
telegram.api_id = 37462587
telegram.api_hash = 35c8bc7cd010dd61eb5a123e2722be41
telegram.session_string = 1BAAOMTQ5LjE1NC4xNjcuOTEAUH1G1uC4mMdqGaXNOcR065VVmuGzwx+XcMAriyt1/m2H0GjGlcxiOPQ1a84arWKw3s7u5SwFKYRDwDSDTFz5r0pNUcYKAxQ/WwPJ9cJ2NaiVVWYjlkJ06nPzL1V6gC5XOn4+7Qvx2c1eeIggi4UmgpS5n1HyTWVYF0SxnM9o9fSR+KolzCxy8154MAG4GnBUG18LGSjLr6/MvB9FDpf+/uWsIy24h6Pj4SPad9Vd1FJGycla9ZKTXA5ipKWrjJmBLOzycAY43VSl5xVFBO5MDdlAgb+QtPTR3WfF6HX+CeFmWPAyOgpaZz1l094XAk6NPMpxxX2OrXztpi6pUoVWQeg=
telegram.channel_username = @donanimhabersicakfirsatlar
```

## Seçenek 3: .env Dosyası Kullanın (Geçici)

Firebase Functions'da `.env` dosyası kullanabilirsiniz (daha yeni Firebase CLI versiyonları).

`functions/.env` dosyası oluşturun:
```
TELEGRAM_API_ID=37462587
TELEGRAM_API_HASH=35c8bc7cd010dd61eb5a123e2722be41
TELEGRAM_SESSION_STRING=1BAAOMTQ5LjE1NC4xNjcuOTEAUH1G1uC4mMdqGaXNOcR065VVmuGzwx+XcMAriyt1/m2H0GjGlcxiOPQ1a84arWKw3s7u5SwFKYRDwDSDTFz5r0pNUcYKAxQ/WwPJ9cJ2NaiVVWYjlkJ06nPzL1V6gC5XOn4+7Qvx2c1eeIggi4UmgpS5n1HyTWVYF0SxnM9o9fSR+KolzCxy8154MAG4GnBUG18LGSjLr6/MvB9FDpf+/uWsIy24h6Pj4SPad9Vd1FJGycla9ZKTXA5ipKWrjJmBLOzycAY43VSl5xVFBO5MDdlAgb+QtPTR3WfF6HX+CeFmWPAyOgpaZz1l094XAk6NPMpxxX2OrXztpi6pUoVWQeg=
TELEGRAM_CHANNEL_USERNAME=@donanimhabersicakfirsatlar
```

Ve `functions/index.js` dosyasında `functions.config()` yerine `process.env` kullanın.

## Hangi Yöntemi Seçmeliyim?

**En kolay:** Seçenek 2 (Firebase Console)
**En doğru:** Seçenek 1 (Node.js güncelle + CLI)





