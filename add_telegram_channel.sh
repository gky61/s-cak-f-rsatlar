#!/bin/bash

# Telegram Bot'una yeni kanal ekleme script'i
# Kullanım: ./add_telegram_channel.sh

echo "📡 Telegram Bot Kanal Ekleme"
echo "============================"
echo ""

# Oracle Cloud bilgileri (deploy_oracle.sh'den alındı)
ORACLE_IP="89.168.102.145"
SSH_KEY="$HOME/Downloads/ssh-key-2025-11-18.key"

# SSH key kontrolü
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ SSH key dosyası bulunamadı: $SSH_KEY"
    exit 1
fi

# Doğru kullanıcıyı bul (opc veya ubuntu)
SSH_USER=""
for user in "opc" "ubuntu"; do
    echo "🔍 $user kullanıcısı test ediliyor..."
    if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$user@$ORACLE_IP" "echo 'test'" >/dev/null 2>&1; then
        SSH_USER="$user"
        echo "✅ $user kullanıcısı ile bağlantı başarılı!"
        break
    fi
done

if [ -z "$SSH_USER" ]; then
    echo "❌ Oracle Cloud'a bağlanılamadı!"
    echo "Lütfen IP adresini ve SSH key dosyasını kontrol edin."
    exit 1
fi

echo "🔗 Oracle Cloud IP: $ORACLE_IP"
echo "👤 SSH Kullanıcı: $SSH_USER"
echo "🔑 SSH Key: $SSH_KEY"
echo ""

# SSH komutunu oluştur
if [ -n "$SSH_KEY" ]; then
    SSH_CMD="ssh -i $SSH_KEY $SSH_USER@$ORACLE_IP"
else
    SSH_CMD="ssh $SSH_USER@$ORACLE_IP"
fi

# Yeni kanal
NEW_CHANNEL="@indirimkaplani"

echo ""
echo "🔍 Mevcut kanallar kontrol ediliyor..."

# Bot dizinini bul
BOT_DIR=""
for dir in "~/sicak-firsatlar" "~/sicak_firsatlar_bot" "/home/$SSH_USER/sicak-firsatlar" "/home/$SSH_USER/sicak_firsatlar_bot"; do
    if $SSH_CMD "test -f $dir/.env" 2>/dev/null; then
        BOT_DIR="$dir"
        echo "✅ Bot dizini bulundu: $BOT_DIR"
        break
    fi
done

if [ -z "$BOT_DIR" ]; then
    echo "❌ Bot dizini bulunamadı!"
    echo "Lütfen bot dizininin yolunu kontrol edin."
    exit 1
fi

# .env dosyasını kontrol et ve mevcut kanalları göster
CURRENT_CHANNELS=$($SSH_CMD "cat $BOT_DIR/.env 2>/dev/null | grep -E 'TELEGRAM_CHANNELS|SOURCE_CHANNELS' | head -1" 2>/dev/null)

if [ -z "$CURRENT_CHANNELS" ]; then
    echo "⚠️ .env dosyasında TELEGRAM_CHANNELS bulunamadı!"
    echo "📝 Yeni kanal listesi oluşturuluyor..."
    
    # .env dosyasına yeni satır ekle
    $SSH_CMD "cd $BOT_DIR && echo 'TELEGRAM_CHANNELS=$NEW_CHANNEL' >> .env" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ Kanal eklendi: $NEW_CHANNEL"
    else
        echo "❌ Hata: Kanal eklenemedi!"
        exit 1
    fi
else
    echo "📋 Mevcut kanallar: $CURRENT_CHANNELS"
    
    # Mevcut kanalları çıkar
    CURRENT_VALUE=$(echo "$CURRENT_CHANNELS" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    
    # Kanal zaten var mı kontrol et
    if echo "$CURRENT_VALUE" | grep -q "$NEW_CHANNEL"; then
        echo "ℹ️  Kanal zaten mevcut: $NEW_CHANNEL"
        echo "✅ Değişiklik yapılmadı."
    else
        # Yeni kanalı ekle (virgülle ayır)
        UPDATED_VALUE="$CURRENT_VALUE,$NEW_CHANNEL"
        
        # .env dosyasını güncelle
        ENV_VAR_NAME=$(echo "$CURRENT_CHANNELS" | cut -d'=' -f1)
        
        echo "➕ Yeni kanal ekleniyor: $NEW_CHANNEL"
        
        # .env dosyasını güncelle (sed ile)
        $SSH_CMD "cd $BOT_DIR && sed -i 's|^${ENV_VAR_NAME}=.*|${ENV_VAR_NAME}=${UPDATED_VALUE}|' .env" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ Kanal başarıyla eklendi!"
            echo "📋 Güncellenmiş kanallar: $UPDATED_VALUE"
        else
            echo "❌ Hata: Kanal eklenemedi!"
            exit 1
        fi
    fi
fi

echo ""
echo "🔄 Bot yeniden başlatılıyor..."

# Bot'u durdur
$SSH_CMD "pkill -f telegram_bot.py" 2>/dev/null
sleep 2

# Bot'u başlat
$SSH_CMD "cd $BOT_DIR && source venv/bin/activate 2>/dev/null && nohup python telegram_bot.py > logs/bot.log 2>&1 &" 2>/dev/null

sleep 3

# Bot durumunu kontrol et
echo ""
echo "📊 Bot durumu:"
$SSH_CMD "ps aux | grep telegram_bot.py | grep -v grep" 2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Bot başarıyla yeniden başlatıldı!"
    echo ""
    echo "📝 Logları görmek için:"
    echo "   $SSH_CMD 'tail -f $BOT_DIR/logs/bot.log'"
else
    echo ""
    echo "⚠️  Bot başlatılamadı! Lütfen manuel olarak kontrol edin."
fi

echo ""
echo "============================"
echo "✨ İşlem tamamlandı!"
echo ""
echo "📡 Bot şu kanalları dinliyor:"
$SSH_CMD "cat $BOT_DIR/.env | grep -E 'TELEGRAM_CHANNELS|SOURCE_CHANNELS'" 2>/dev/null

