#!/bin/bash
set -e

# ==============================================================================
# FırsatKolik iOS CI/CD — Geçici macOS Keychain ve Sertifika Kurulum Betiği
# ==============================================================================

echo "🔐 [1/4] Geçici keychain oluşturuluyor..."
KEYCHAIN_PATH=$RUNNER_TEMP/build.keychain
KEYCHAIN_PASSWORD=$(openssl rand -base64 20)

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

echo "📜 [2/4] Apple Dağıtım Sertifikası (.p12) çözümleniyor ve yükleniyor..."
CERTIFICATE_PATH=$RUNNER_TEMP/build_certificate.p12
echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o "$CERTIFICATE_PATH"

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
  "$KEYCHAIN_PATH"

security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | tr -d '"')

echo "📋 [3/4] Apple Provisioning Profile (.mobileprovision) yükleniyor..."
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles

PROFILE_PATH=$RUNNER_TEMP/build_profile.mobileprovision
echo -n "$BUILD_PROVISION_PROFILE_BASE64" | base64 --decode -o "$PROFILE_PATH"

# Profile UUID ve Name değerlerini dinamik oku
PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print UUID" /dev/stdin <<< $(security cms -D -i "$PROFILE_PATH"))
PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print Name" /dev/stdin <<< $(security cms -D -i "$PROFILE_PATH"))
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
