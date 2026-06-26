#!/bin/bash

# Bot loglarını kontrol etme scripti
# Kullanım: ./check_bot_logs.sh

SSH_KEY="$HOME/Desktop/ssh-key-2025-11-20.key"
HOST="ubuntu@89.168.102.145"
LOG_PATH="/home/ubuntu/sicak_firsatlar_bot/logs/bot.log"

echo "🤖 Bot Logları Kontrol Ediliyor..."
echo ""

# Son 50 satırı göster
echo "📋 Son 50 Satır:"
echo "----------------------------------------"
ssh -i "$SSH_KEY" "$HOST" "tail -50 $LOG_PATH"
echo ""
echo "----------------------------------------"
echo ""

# Önemli logları filtrele
echo "🔍 Önemli Loglar (Son 100 satırdan):"
echo "----------------------------------------"
ssh -i "$SSH_KEY" "$HOST" "tail -100 $LOG_PATH | grep -E 'MESAJ|Link|İşleniyor|HTML|AI|Firestore|Kaydedildi|hata|ERROR|Exception|✅|❌'"
echo ""
echo "----------------------------------------"
echo ""

# Son hata varsa göster
echo "⚠️ Son Hatalar:"
echo "----------------------------------------"
ssh -i "$SSH_KEY" "$HOST" "tail -200 $LOG_PATH | grep -E 'ERROR|Exception|Traceback|❌' | tail -10"
echo ""
echo "----------------------------------------"



