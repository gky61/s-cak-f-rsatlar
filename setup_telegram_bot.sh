#!/bin/bash

# Telegram Bot Kurulum Scripti
# Bu script Telegram bot'unuzu kurmanıza yardımcı olur

echo "🤖 Telegram Bot Kurulum Scripti"
echo "================================"
echo ""

# 1. Bot Token Kontrolü
echo "1️⃣  Bot Token'ınızı girin (BotFather'dan aldığınız token):"
read -r BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    echo "❌ Bot token boş olamaz!"
    exit 1
fi

# 2. Grup ID Kontrolü (opsiyonel)
echo ""
echo "2️⃣  Grup ID'lerinizi girin (virgülle ayırın, boş bırakabilirsiniz - tüm gruplar kabul edilir):"
read -r GROUP_IDS

# 2b. Kanal Username Kontrolü (opsiyonel)
echo ""
echo "2️⃣b Kanal username'lerini girin (örn: @donanimhabersicakfirsatlar, virgülle ayırın, boş bırakabilirsiniz):"
read -r CHANNEL_USERNAMES

# 3. Firebase Functions Config Ayarlama
echo ""
echo "3️⃣  Firebase Functions config ayarlanıyor..."
firebase functions:config:set telegram.bot_token="$BOT_TOKEN"

if [ -n "$GROUP_IDS" ]; then
    firebase functions:config:set telegram.allowed_group_ids="$GROUP_IDS"
    echo "✅ Grup ID'leri ayarlandı: $GROUP_IDS"
else
    echo "ℹ️  Grup ID'leri ayarlanmadı - tüm gruplar kabul edilecek"
fi

if [ -n "$CHANNEL_USERNAMES" ]; then
    firebase functions:config:set telegram.allowed_channels="$CHANNEL_USERNAMES"
    echo "✅ Kanal username'leri ayarlandı: $CHANNEL_USERNAMES"
else
    echo "ℹ️  Kanal username'leri ayarlanmadı - tüm kanallar kabul edilecek"
fi

# 4. Paketleri Yükleme
echo ""
echo "4️⃣  Functions paketleri yükleniyor..."
cd functions
npm install
cd ..

# 5. Function'ı Deploy Etme
echo ""
echo "5️⃣  Function deploy ediliyor..."
firebase deploy --only functions:telegramWebhook

# 6. Webhook URL'ini Alma
echo ""
echo "6️⃣  Webhook URL'i alınıyor..."
PROJECT_ID=$(firebase projects:list | grep -oP '(?<=\* ).*' | head -1)
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(cat .firebaserc | grep -oP '(?<="default": ")[^"]*')
fi

WEBHOOK_URL="https://us-central1-${PROJECT_ID}.cloudfunctions.net/telegramWebhook"
echo "✅ Webhook URL: $WEBHOOK_URL"

# 7. Webhook'u Telegram'a Kaydetme
echo ""
echo "7️⃣  Webhook Telegram'a kaydediliyor..."
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${WEBHOOK_URL}\"}")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ Webhook başarıyla ayarlandı!"
else
    echo "❌ Webhook ayarlanırken hata oluştu:"
    echo "$RESPONSE"
    exit 1
fi

# 8. Webhook Bilgilerini Kontrol Etme
echo ""
echo "8️⃣  Webhook bilgileri kontrol ediliyor..."
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo" | python3 -m json.tool

echo ""
echo "🎉 Kurulum tamamlandı!"
echo ""
echo "📝 Sonraki adımlar:"
echo "1. Bot'unuzu Telegram grubunuza ekleyin"
echo "2. Gruba bir test mesajı gönderin"
echo "3. Firebase Console > Firestore > deals koleksiyonunda yeni deal'i kontrol edin"
echo ""
echo "🔍 Logları kontrol etmek için:"
echo "   firebase functions:log --only telegramWebhook"

