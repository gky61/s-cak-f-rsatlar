#!/bin/bash

# Yerel Telegram Bot Başlatma Scripti
# Bu script botu yerel bilgisayarınızda (Mac) çalıştırır ve Firestore'a yazar.

cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR/cloud-run-bot"

# Firebase Key (Hizmet hesabı) yolunu ayarla
export GOOGLE_APPLICATION_CREDENTIALS="/Users/gokayalemdar/Desktop/SICAK FIRSATLAR/firebase_key.json"

# Ortam Değişkenleri
export TELEGRAM_API_ID="37462587"
export TELEGRAM_API_HASH="35c8bc7cd010dd61eb5a123e2722be41"
export TELEGRAM_SESSION_STRING="1BAAOMTQ5LjE1NC4xNjcuOTEAUA2PIWkEB4/jpg4uLV0e0C+mdS4xxJ8apDOUoZZAQdmZcDZJBucb3NaXYn3ZXVK+6b3pN0V4asPtBlr4DFeejT80vDLC6xD7EkasDK8PG3EQf9lZPi3OjLwLZvn3NZA2nEI7E/zD8Vcdaoa06oNPXG/QnATe9qtRyeB7/ePZwtYJhjGzEVEzED2HPSUMcAciYCsF67GF8q2VV7ap9Q1lOoTWwMYXRFRAuznP3NByWsDNLnVMhZvOddkdngCBXPapwKuojIm1wvkn6eJviRf1McN2ob89EZU9gv99BtJ4tqPE43tTyW+FiMOpLvngqiEtJIOe9/dXY34hvDFWAB5gSiM="
export TELEGRAM_CHANNELS="@indirimkaplani,-1003423704050,-3423704050"

# Geçerli Gemini API anahtarını buraya yerleştirin
export GEMINI_API_KEY="AIzaSyCAxNjruy70BhZedYaBZdm_mSpUHsR3Yr0"

echo "🤖 Telegram Fırsat Geçmişi Yerelde Çekiliyor..."
echo "📂 Google Credentials: $GOOGLE_APPLICATION_CREDENTIALS"
echo "📡 Dinlenecek Kanallar: $TELEGRAM_CHANNELS"
echo ""

# Botu çalıştır
node fetch_history.js
