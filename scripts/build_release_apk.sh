#!/bin/bash

# Release APK oluşturma scripti
# Bu script optimizasyonlu release APK oluşturur

echo "🚀 Release APK oluşturuluyor..."
echo ""

# Proje dizinine git
cd "$(dirname "$0")/.."

# Flutter clean
echo "📦 Temizlik yapılıyor..."
flutter clean

# Paketleri yükle
echo "📥 Paketler yükleniyor..."
flutter pub get

# Release APK oluştur
echo "🔨 Release APK oluşturuluyor (bu biraz zaman alabilir)..."
flutter build apk --release

# APK'nın yerini göster
echo ""
echo "✅ Release APK başarıyla oluşturuldu!"
echo "📍 APK konumu:"
echo "   $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "💡 Bu APK, debug APK'dan çok daha hızlı ve optimize edilmiştir!"
echo "   Boyut da daha küçük olacaktır."






