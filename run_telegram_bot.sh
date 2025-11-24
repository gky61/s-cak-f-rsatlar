#!/bin/bash

# Telegram Bot Çalıştırma Scripti

echo "🤖 Telegram Bot başlatılıyor..."

# Virtual environment kontrolü
if [ ! -d "venv" ]; then
    echo "📦 Virtual environment oluşturuluyor..."
    python3 -m venv venv
fi

# Virtual environment'ı aktif et
source venv/bin/activate

# Bağımlılıkları yükle
echo "📥 Bağımlılıklar yükleniyor..."
pip install -r requirements.txt

# .env dosyası kontrolü
if [ ! -f ".env" ]; then
    echo "⚠️ .env dosyası bulunamadı!"
    echo "📝 .env.example dosyasını kopyalayıp düzenleyin:"
    echo "   cp .env.example .env"
    exit 1
fi

# Firebase key kontrolü
if [ ! -f "firebase_key.json" ]; then
    echo "⚠️ firebase_key.json dosyası bulunamadı!"
    echo "📝 Firebase Console'dan service account key indirip firebase_key.json olarak kaydedin."
    exit 1
fi

# Logs klasörünü oluştur
mkdir -p logs

# Botu çalıştır
echo "🚀 Bot çalıştırılıyor..."
python telegram_bot.py





