#!/bin/bash

# Firebase Function'ı manuel olarak tetikle
# Cloud Scheduler üzerinden

echo "🚀 Function'ı manuel tetikliyorum..."
echo ""

# Pub/Sub topic'i bul ve mesaj gönder
TOPIC="firebase-schedule-fetchChannelMessages-us-central1"
PROJECT="sicak-firsatlar-e6eae"

echo "📡 Pub/Sub topic: $TOPIC"
echo "📦 Project: $PROJECT"
echo ""

# gcloud ile mesaj gönder
gcloud pubsub topics publish "$TOPIC" \
  --message '{"data":"manual trigger"}' \
  --project "$PROJECT" 2>/dev/null

if [ $? -eq 0 ]; then
  echo "✅ Function tetiklendi!"
  echo ""
  echo "📊 Logları kontrol etmek için:"
  echo "   firebase functions:log --only fetchChannelMessages"
else
  echo "⚠️  gcloud komutu bulunamadı veya hata oluştu"
  echo ""
  echo "💡 Alternatif: Firebase Console'dan manuel tetikleyin:"
  echo "   1. Firebase Console > Functions > fetchChannelMessages"
  echo "   2. 'Test' sekmesine gidin"
  echo "   3. 'Test the function' butonuna tıklayın"
fi





