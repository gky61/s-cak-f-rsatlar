#!/bin/bash
set -e

# ==============================================================================
# FırsatKolik iOS CI/CD — App Store Connect / TestFlight IPA Yükleme Betiği
# ==============================================================================
# 1. Öncelikli Yöntem: Fastlane pilot / upload_to_testflight (App Store Connect API v1)
#    - Apple'ın modern REST API standardını kullanır.
#    - xcrun altool deprecation uyarılarından ve ağ kopmalarından etkilenmez.
#    - skip_waiting_for_build_processing ile 10x macOS kotasını korur.
# 2. İkincil / Yedek Yöntem: xcrun altool (Legacy Fallback)
# ==============================================================================

IPA_PATH="$1"

if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
  echo "❌ Hata: Yüklenecek .ipa dosyası bulunamadı: $IPA_PATH"
  exit 1
fi

echo "🚀 [1/3] App Store Connect API Anahtarı hazırlanıyor..."
API_KEY_DIR=~/.appstoreconnect/private_keys
mkdir -p "$API_KEY_DIR"
KEY_FILE="$API_KEY_DIR/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
echo "$APP_STORE_CONNECT_PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

echo "🏎️ [2/3] TestFlight Yükleme Motoru Başlatılıyor..."

# FASTLANE KULLANIMI (Öncelikli Modern Yöntem)
if command -v fastlane &> /dev/null; then
  echo "✅ Fastlane tespit edildi. App Store Connect API üzerinden TestFlight'a yükleniyor..."
  export IPA_FILE="$IPA_PATH"
  
  if fastlane --version > /dev/null 2>&1; then
    fastlane beta --fastfile ios_ci/Fastfile
    echo "🎉 Tebrikler! Fastlane ile FırsatKolik TestFlight'a başarıyla yüklendi!"
    exit 0
  else
    echo "⚠️ Fastlane çalışırken bir sorunla karşılaşıldı. Yedek mekanizma (xcrun altool) devreye giriyor..."
  fi
fi

# YEDEK YÖNTEM: XCRUN ALTOOL (Fallback)
echo "📦 [3/3] Yedek Yöntem: xcrun altool ile yükleme deneniyor..."

echo "   -> .ipa doğrulanıyor (altool validation)..."
xcrun altool --validate-app \
  -f "$IPA_PATH" \
  -t ios \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

echo "   -> .ipa yükleniyor (altool upload)..."
xcrun altool --upload-app \
  -f "$IPA_PATH" \
  -t ios \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

echo "🎉 Tebrikler! FırsatKolik iOS sürümü başarıyla TestFlight'a yüklendi!"
