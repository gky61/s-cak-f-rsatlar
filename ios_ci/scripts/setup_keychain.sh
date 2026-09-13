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

# macOS Keychain'e içe aktarma (Failsafe: OpenSSL 3 PBKDF2 ise legacy 3DES formatına otomatik dönüştür)
if ! security import "$CERTIFICATE_PATH" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH" 2>/dev/null; then
  echo "   ⚠️ Standart import başarısız oldu (OpenSSL 3 PBKDF2 formatı tespit edildi). Legacy 3DES formatına dönüştürülüyor..."
  openssl pkcs12 -in "$CERTIFICATE_PATH" -nodes -passin "pass:$P12_PASSWORD" -out "$RUNNER_TEMP/temp_cert_key.pem" 2>/dev/null || true
  if [ -f "$RUNNER_TEMP/temp_cert_key.pem" ]; then
    openssl pkcs12 -export -in "$RUNNER_TEMP/temp_cert_key.pem" -out "$CERTIFICATE_PATH" -passout "pass:$P12_PASSWORD" -legacy 2>/dev/null || \
    openssl pkcs12 -export -in "$RUNNER_TEMP/temp_cert_key.pem" -out "$CERTIFICATE_PATH" -passout "pass:$P12_PASSWORD" 2>/dev/null || true
    rm -f "$RUNNER_TEMP/temp_cert_key.pem"
    security import "$CERTIFICATE_PATH" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
  fi
fi

security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH" || true

security default-keychain -s "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | tr -d '"')
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

echo "   Sertifika kimliği doğrulanıyor (codesign identity):"
security find-identity -v -p codesigning "$KEYCHAIN_PATH"

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

# ==================== Share Extension Provisioning Profile ====================
if [ -n "$SHARE_EXT_PROVISION_PROFILE_BASE64" ]; then
  echo "📋 [3b/4] Share Extension Provisioning Profile (.mobileprovision) yükleniyor..."
  
  SHARE_EXT_PROFILE_PATH="$RUNNER_TEMP/share_ext_profile.mobileprovision"
  echo "$SHARE_EXT_PROVISION_PROFILE_BASE64" | openssl base64 -d -A -out "$SHARE_EXT_PROFILE_PATH" 2>/dev/null || \
  echo "$SHARE_EXT_PROVISION_PROFILE_BASE64" | base64 -D -o "$SHARE_EXT_PROFILE_PATH" 2>/dev/null || \
  echo "$SHARE_EXT_PROVISION_PROFILE_BASE64" | base64 -d > "$SHARE_EXT_PROFILE_PATH" 2>/dev/null || \
  echo "$SHARE_EXT_PROVISION_PROFILE_BASE64" | base64 --decode > "$SHARE_EXT_PROFILE_PATH"

  if [ -f "$SHARE_EXT_PROFILE_PATH" ] && [ -s "$SHARE_EXT_PROFILE_PATH" ]; then
    security cms -D -i "$SHARE_EXT_PROFILE_PATH" > "$RUNNER_TEMP/share_ext_profile.plist"
    
    SHARE_EXT_UUID=$(/usr/libexec/PlistBuddy -c "Print UUID" "$RUNNER_TEMP/share_ext_profile.plist")
    SHARE_EXT_NAME=$(/usr/libexec/PlistBuddy -c "Print Name" "$RUNNER_TEMP/share_ext_profile.plist")
    echo "   Share Extension Profile UUID: $SHARE_EXT_UUID"
    echo "   Share Extension Profile Name: $SHARE_EXT_NAME"
    
    cp "$SHARE_EXT_PROFILE_PATH" ~/Library/MobileDevice/Provisioning\ Profiles/$SHARE_EXT_UUID.mobileprovision
    
    # ExportOptions plist dosyalarına Share Extension profil adını enjekte et
    for plist in ios_ci/ExportOptions_*.plist; do
      if [ -f "$plist" ]; then
        /usr/libexec/PlistBuddy -c "Set :provisioningProfiles:com.firsatkolik.app.ShareExtension '$SHARE_EXT_NAME'" "$plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:com.firsatkolik.app.ShareExtension string '$SHARE_EXT_NAME'" "$plist" 2>/dev/null || true
      fi
    done

    # project.pbxproj içindeki ShareExtension PROVISIONING_PROFILE_SPECIFIER değerini gerçek profil adıyla güncelle
    if [ -n "$SHARE_EXT_NAME" ]; then
      sed -i '' "s/PROVISIONING_PROFILE_SPECIFIER = \"FirsatKolik ShareExtension Profile\";/PROVISIONING_PROFILE_SPECIFIER = \"$SHARE_EXT_NAME\";/g" ios/Runner.xcodeproj/project.pbxproj 2>/dev/null || true
    fi
  else
    echo "   ⚠️ Share Extension profili boş veya çözümlenemedi. Extension imzalanmadan devam edilecek."
  fi
else
  echo "   ℹ️ SHARE_EXT_PROVISION_PROFILE_BASE64 tanımlanmamış. Share Extension profili atlanıyor."
fi

# Release ve Debug xcconfig dosyalarına dinamik manuel imzalama ayarlarını enjekte et
for xcconfig in ios/Flutter/Release.xcconfig ios/Flutter/Debug.xcconfig; do
  if [ -f "$xcconfig" ]; then
    cat <<EOF >> "$xcconfig"

// CI/CD Manual Code Signing Configuration
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = 973W9DTDY9
PROVISIONING_PROFILE_SPECIFIER = $PROFILE_NAME
PROVISIONING_PROFILE = $PROFILE_UUID
CODE_SIGN_IDENTITY = Apple Distribution
CODE_SIGN_IDENTITY[sdk=iphoneos*] = Apple Distribution
CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES
ENABLE_USER_SCRIPT_SANDBOXING = NO
EOF
  fi
done

echo "✅ [4/4] Keychain ve Sertifika yapılandırması başarıyla tamamlandı!"
