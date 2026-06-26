#!/bin/bash

# Oracle Cloud'daki Telegram Bot'unu günceller ve yeniden başlatır
# Kullanım: ./update_oracle_bot.sh oracle-ip kullanici-adi [ssh-key-path]

HOST=$1
USER=$2
KEY_PATH=$3

if [ -z "$HOST" ] || [ -z "$USER" ]; then
    echo "❌ Kullanım: $0 <host> <user> [ssh-key]"
    echo "Örnek: $0 123.45.67.89 ubuntu ~/.ssh/oracle.key"
    exit 1
fi

# SSH komutunu oluştur
if [ -n "$KEY_PATH" ]; then
    SSH_CMD="ssh -i $KEY_PATH $USER@$HOST"
else
    SSH_CMD="ssh $USER@$HOST"
fi

echo "🔄 Oracle Cloud Bot Güncelleme Başlatılıyor..."
echo "================================================"
echo ""

# Bot'u durdur
echo "⏸️  Bot durduruluyor..."
$SSH_CMD "pkill -f telegram_bot.py"
sleep 2

# Git pull
echo "📥 Güncellemeler çekiliyor..."
$SSH_CMD "cd ~/SICAK_FIRSATLAR && git pull origin main"

# Bot'u başlat
echo "🚀 Bot başlatılıyor..."
$SSH_CMD "cd ~/SICAK_FIRSATLAR && nohup python3 telegram_bot.py > logs/bot.log 2>&1 &"
sleep 3

# Durum kontrolü
echo ""
echo "✅ Bot güncellendi ve yeniden başlatıldı!"
echo ""
echo "📊 Bot durumu kontrol ediliyor..."
$SSH_CMD "ps aux | grep telegram_bot | grep -v grep"

echo ""
echo "================================================"
echo "✨ Güncelleme tamamlandı!"
echo ""
echo "📝 Logları görmek için:"
echo "   $SSH_CMD 'tail -f ~/SICAK_FIRSATLAR/logs/bot.log'"










