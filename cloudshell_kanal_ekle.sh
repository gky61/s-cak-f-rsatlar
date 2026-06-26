#!/bin/bash

# Oracle Cloud Shell'den bot sunucusuna kanal ekleme script'i

echo "📡 Telegram Bot Kanal Ekleme (Oracle Cloud Shell)"
echo "================================================="
echo ""

# Yeni kanal
NEW_CHANNEL="@indirimkaplani"

echo "🔍 Bot sunucusu aranıyor..."

# Compute instance'ları listele
echo "📋 Mevcut compute instance'lar:"
oci compute instance list --compartment-id $(oci iam compartment list --all --query "data[?name=='root'].id | [0]" --raw-output) --query "data[*].{Name:display-name,IP:lifecycle-state,OCID:id}" --output table 2>/dev/null || echo "Instance'lar listelenemedi"

echo ""
echo "💡 Bot sunucusunun IP adresini ve kullanıcı adını (opc veya ubuntu) girmeniz gerekiyor."
read -p "Bot sunucusu IP adresi: " SERVER_IP
read -p "SSH kullanıcı adı (opc veya ubuntu): " SSH_USER

if [ -z "$SERVER_IP" ] || [ -z "$SSH_USER" ]; then
    echo "❌ IP adresi ve kullanıcı adı gereklidir!"
    exit 1
fi

# Bot dizinini bul
echo ""
echo "🔍 Bot dizini aranıyor..."
BOT_DIR=""

# Önce bağlantıyı test et
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "echo 'Bağlantı başarılı'" >/dev/null 2>&1; then
    echo "✅ Sunucuya bağlantı başarılı!"
    
    # Olası dizinleri kontrol et
    for dir in "~/sicak-firsatlar" "~/sicak_firsatlar_bot" "/home/$SSH_USER/sicak-firsatlar" "/home/$SSH_USER/sicak_firsatlar_bot"; do
        if ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "test -f $dir/.env" 2>/dev/null; then
            BOT_DIR="$dir"
            echo "✅ Bot dizini bulundu: $BOT_DIR"
            break
        fi
    done
    
    if [ -z "$BOT_DIR" ]; then
        echo "⚠️  Bot dizini bulunamadı, manuel olarak arayalım..."
        ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "find ~ -name 'telegram_bot.py' -type f 2>/dev/null | head -1" | while read bot_file; do
            if [ -n "$bot_file" ]; then
                BOT_DIR=$(dirname "$bot_file")
                echo "✅ Bot dosyası bulundu: $bot_file"
                echo "📂 Bot dizini: $BOT_DIR"
            fi
        done
    fi
else
    echo "❌ Sunucuya bağlanılamadı!"
    exit 1
fi

if [ -z "$BOT_DIR" ]; then
    echo "❌ Bot dizini bulunamadı!"
    echo "Lütfen bot dizininin yolunu manuel olarak girin:"
    read -p "Bot dizini yolu: " BOT_DIR
fi

echo ""
echo "📋 Mevcut kanallar kontrol ediliyor..."

# .env dosyasını kontrol et
CURRENT_CHANNELS=$(ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "cat $BOT_DIR/.env 2>/dev/null | grep -E 'TELEGRAM_CHANNELS|SOURCE_CHANNELS' | head -1" 2>/dev/null)

if [ -z "$CURRENT_CHANNELS" ]; then
    echo "⚠️  .env dosyasında TELEGRAM_CHANNELS bulunamadı!"
    echo "📝 Yeni kanal listesi oluşturuluyor..."
    
    ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "cd $BOT_DIR && echo 'TELEGRAM_CHANNELS=$NEW_CHANNEL' >> .env" 2>/dev/null
    
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
        
        # .env dosyasını güncelle
        ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "cd $BOT_DIR && sed -i 's|^${ENV_VAR_NAME}=.*|${ENV_VAR_NAME}=${UPDATED_VALUE}|' .env" 2>/dev/null
        
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
ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "pkill -f telegram_bot.py" 2>/dev/null
sleep 2

# Bot'u başlat
ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "cd $BOT_DIR && source venv/bin/activate 2>/dev/null && nohup python telegram_bot.py > logs/bot.log 2>&1 &" 2>/dev/null

sleep 3

# Bot durumunu kontrol et
echo ""
echo "📊 Bot durumu:"
ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "ps aux | grep telegram_bot.py | grep -v grep" 2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Bot başarıyla yeniden başlatıldı!"
    echo ""
    echo "📝 Logları görmek için:"
    echo "   ssh $SSH_USER@$SERVER_IP 'tail -f $BOT_DIR/logs/bot.log'"
else
    echo ""
    echo "⚠️  Bot başlatılamadı! Lütfen manuel olarak kontrol edin."
fi

echo ""
echo "============================"
echo "✨ İşlem tamamlandı!"
echo ""
echo "📡 Bot şu kanalları dinliyor:"
ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "cat $BOT_DIR/.env | grep -E 'TELEGRAM_CHANNELS|SOURCE_CHANNELS'" 2>/dev/null



