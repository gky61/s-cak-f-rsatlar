#!/bin/bash
set -e

# ==============================================================================
# FırsatKolik iOS CI/CD — App Store Connect / TestFlight IPA Yükleme Betiği
# ==============================================================================

IPA_PATH="$1"

if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
  echo "❌ HATA: Yüklenecek .ipa dosyası bulunamadı: $IPA_PATH"
  exit 1
fi

echo "🔍 [0/3] App Store Connect kimlik bilgileri kontrol ediliyor..."
if [ -z "$APP_STORE_CONNECT_KEY_ID" ]; then
  echo "❌ HATA: APP_STORE_CONNECT_KEY_ID secret'ı boş veya tanımlanmamış!"
  exit 1
fi
if [ -z "$APP_STORE_CONNECT_ISSUER_ID" ]; then
  echo "❌ HATA: APP_STORE_CONNECT_ISSUER_ID secret'ı boş veya tanımlanmamış!"
  exit 1
fi
if [ -z "$APP_STORE_CONNECT_PRIVATE_KEY" ]; then
  echo "❌ HATA: APP_STORE_CONNECT_PRIVATE_KEY secret'ı boş veya tanımlanmamış!"
  exit 1
fi

echo "🚀 [1/3] App Store Connect API Anahtarı hazırlanıyor..."
API_KEY_DIR=~/.appstoreconnect/private_keys
mkdir -p "$API_KEY_DIR"
KEY_FILE="$API_KEY_DIR/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
echo "$APP_STORE_CONNECT_PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

# xcrun altool için yedek standart dizine de kopyala
mkdir -p ~/.private_keys
cp -f "$KEY_FILE" ~/.private_keys/

echo "🏎️ [2/3] TestFlight Yükleme Motoru Başlatılıyor..."

# FASTLANE KULLANIMI (Öncelikli Modern Yöntem)
if command -v fastlane &> /dev/null; then
  echo "✅ Fastlane tespit edildi. App Store Connect API üzerinden TestFlight'a yükleniyor..."
  export IPA_FILE="$IPA_PATH"
  
  mkdir -p fastlane
  cp -f ios_ci/Fastfile fastlane/Fastfile

  if fastlane ios beta ipa:"$IPA_PATH"; then
    echo "🎉 Tebrikler! Fastlane ile FırsatKolik TestFlight'a başarıyla yüklendi!"
    exit 0
  else
    echo "⚠️ Fastlane çalışırken bir sorunla karşılaşıldı. Yedek mekanizma (xcrun altool) devreye giriyor..."
  fi
fi

# YEDEK YÖNTEM: XCRUN ALTOOL (Fallback)
echo "📦 [3/3] Yedek Yöntem: xcrun altool ile doğrudan yükleme deneniyor..."
xcrun altool --upload-app \
  -f "$IPA_PATH" \
  -t ios \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

echo "🎉 Tebrikler! FırsatKolik iOS sürümü başarıyla TestFlight'a yüklendi!"
