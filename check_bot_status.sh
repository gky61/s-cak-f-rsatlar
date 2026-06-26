#!/bin/bash

# Oracle Cloud Bot Durum Kontrolü

SERVER_IP="89.168.102.145"
SSH_USER="ubuntu"
SSH_KEY="$HOME/Downloads/ssh-key-2025-11-20.key"

# SSH key kontrolü
if [ ! -f "$SSH_KEY" ]; then
    SSH_KEY="$HOME/Downloads/ssh-key-2025-11-18.key"
fi

if [ ! -f "$SSH_KEY" ]; then
    echo "❌ SSH key bulunamadı!"
    exit 1
fi

echo "🔍 Oracle Cloud Bot Durumu Kontrol Ediliyor..."
echo "=============================================="
echo ""

# 1. Bot process kontrolü
echo "1️⃣ Bot Process Kontrolü:"
ssh -i "$SSH_KEY" -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "ps aux | grep telegram_bot | grep -v grep" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Bot çalışıyor!"
else
    echo "❌ Bot çalışmıyor!"
fi
echo ""

# 2. Bot dizini kontrolü
echo "2️⃣ Bot Dizini Kontrolü:"
ssh -i "$SSH_KEY" -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "cd ~/sicak_firsatlar_bot 2>/dev/null && pwd && ls -la telegram_bot.py .env 2>/dev/null || echo 'Dizin bulunamadı'" 2>/dev/null
echo ""

# 3. Son loglar
echo "3️⃣ Son Loglar (son 20 satır):"
ssh -i "$SSH_KEY" -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "cd ~/sicak_firsatlar_bot 2>/dev/null && tail -20 logs/bot.log 2>/dev/null || tail -20 bot.log 2>/dev/null || echo 'Log dosyası bulunamadı'" 2>/dev/null
echo ""

# 4. .env dosyası kontrolü
echo "4️⃣ .env Dosyası Kontrolü:"
ssh -i "$SSH_KEY" -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "cd ~/sicak_firsatlar_bot 2>/dev/null && cat .env | grep -E 'TELEGRAM_CHANNELS|SOURCE_CHANNELS|API_ID|API_HASH' 2>/dev/null || echo '.env dosyası bulunamadı'" 2>/dev/null
echo ""

# 5. Python process kontrolü
echo "5️⃣ Python Process Kontrolü:"
ssh -i "$SSH_KEY" -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "ps aux | grep python | grep -v grep" 2>/dev/null
echo ""

echo "=============================================="
echo "✅ Kontrol tamamlandı!"



