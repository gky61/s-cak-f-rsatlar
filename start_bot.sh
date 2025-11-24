#!/bin/bash

# Python Telegram Bot'u başlatma scripti
# Sürekli çalıştırır (her 5 dakikada bir)

cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"

# Virtual environment'ı aktif et
source venv/bin/activate

# Bot'u çalıştır (her 5 dakikada bir)
while true; do
    echo "🔄 Bot başlatılıyor... $(date)"
    python telegram_bot.py
    echo "⏸️ Bot durdu, 5 dakika bekleniyor... $(date)"
    sleep 300  # 5 dakika = 300 saniye
done





