#!/bin/bash
set -e

# ==============================================================================
# FırsatKolik iOS CI/CD — Geçici macOS Keychain ve Sertifika Kurulum Betiği
# ==============================================================================

echo "🔍 [0/4] Secret ve ortam değişkenleri kontrol ediliyor..."
if [ -z "$BUILD_CERTIFICATE_BASE64" ]; then
  echo "❌ HATA: BUILD_CERTIFICATE_BASE64 secret'ı boş veya tanımlanmamış!"
  exit 1
fi
if [ -z "$P12_PASSWORD" ]; then
  echo "❌ HATA: P12_PASSWORD secret'ı boş veya tanımlanmamış!"
  exit 1
fi
if [ -z "$BUILD_PROVISION_PROFILE_BASE64" ]; then
  echo "❌ HATA: BUILD_PROVISION_PROFILE_BASE64 secret'ı boş veya tanımlanmamış!"
  exit 1
fi

echo "🔐 [1/4] Geçici keychain oluşturuluyor..."
KEYCHAIN_PATH="$RUNNER_TEMP/app-signing.keychain-db"
KEYCHAIN_PASSWORD=$(openssl rand -base64 20)

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" || true
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

echo "📜 [2/4] Apple Dağıtım Sertifikası (.p12) çözümleniyor ve yükleniyor..."
CERTIFICATE_PATH="$RUNNER_TEMP/build_certificate.p12"

# Güvenli Base64 çözümleme (macOS / Linux uyumlu)
echo "$BUILD_CERTIFICATE_BASE64" | openssl base64 -d -A -out "$CERTIFICATE_PATH" 2>/dev/null || \
echo "$BUILD_CERTIFICATE_BASE64" | base64 -D -o "$CERTIFICATE_PATH" 2>/dev/null || \
echo "$BUILD_CERTIFICATE_BASE64" | base64 -d > "$CERTIFICATE_PATH" 2>/dev/null || \
echo "$BUILD_CERTIFICATE_BASE64" | base64 --decode > "$CERTIFICATE_PATH"

if [ ! -f "$CERTIFICATE_PATH" ] || [ ! -s "$CERTIFICATE_PATH" ]; then
  echo "❌ HATA: P12 sertifikası base64'ten çözülemedi veya boş oluştu!"
  exit 1
fi

security import "$CERTIFICATE_PATH" \
  -P "$P12_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "$KEYCHAIN_PATH"

security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH" || true

security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | tr -d '"')

echo "📋 [3/4] Apple Provisioning Profile (.mobileprovision) yükleniyor..."
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles

PROFILE_PATH="$RUNNER_TEMP/build_profile.mobileprovision"
echo "$BUILD_PROVISION_PROFILE_BASE64" | openssl base64 -d -A -out "$PROFILE_PATH" 2>/dev/null || \
echo "$BUILD_PROVISION_PROFILE_BASE64" | base64 -D -o "$PROFILE_PATH" 2>/dev/null || \
echo "$BUILD_PROVISION_PROFILE_BASE64" | base64 -d > "$PROFILE_PATH" 2>/dev/null || \
echo "$BUILD_PROVISION_PROFILE_BASE64" | base64 --decode > "$PROFILE_PATH"

if [ ! -f "$PROFILE_PATH" ] || [ ! -s "$PROFILE_PATH" ]; then
  echo "❌ HATA: Provisioning profile base64'ten çözülemedi veya boş oluştu!"
  exit 1
fi

# Profil içeriğini geçici dosyaya çıkar ve PlistBuddy ile oku
security cms -D -i "$PROFILE_PATH" > "$RUNNER_TEMP/profile.plist"

PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print UUID" "$RUNNER_TEMP/profile.plist")
PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print Name" "$RUNNER_TEMP/profile.plist")
echo "   Provisioning Profile UUID: $PROFILE_UUID"
echo "   Provisioning Profile Name: $PROFILE_NAME"

cp "$PROFILE_PATH" ~/Library/MobileDevice/Provisioning\ Profiles/$PROFILE_UUID.mobileprovision

# ExportOptions plist dosyalarındaki profil adını dinamik eşitle
for plist in ios_ci/ExportOptions_*.plist; do
  if [ -f "$plist" ]; then
    /usr/libexec/PlistBuddy -c "Set :provisioningProfiles:com.firsatkolik.app '$PROFILE_NAME'" "$plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:com.firsatkolik.app string '$PROFILE_NAME'" "$plist" 2>/dev/null || true
  fi
done

echo "✅ [4/4] Keychain ve Sertifika yapılandırması başarıyla tamamlandı!"
