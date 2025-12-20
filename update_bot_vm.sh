#!/bin/bash
# Oracle Cloud VM'de bot'u güncelleme scripti

echo "🔄 Bot güncelleniyor..."

# Bot klasörüne git
cd ~/sicak_firsatlar_bot

# Eski bot'u durdur
echo "⏹️ Eski bot durduruluyor..."
pkill -f telegram_bot.py

# GitHub'tan yeni kodu çek
echo "📥 Yeni kod indiriliyor..."
git pull origin main

# Bot'u arka planda başlat
echo "🚀 Bot başlatılıyor..."
nohup python3 telegram_bot.py > logs/bot.log 2>&1 &

echo "✅ Bot güncellendi ve başlatıldı!"
echo "📋 Logları görmek için: tail -f ~/sicak_firsatlar_bot/logs/bot.log"

