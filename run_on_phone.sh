#!/bin/bash

echo "📱 Telefon bağlantısı kontrol ediliyor..."
echo ""

# Telefonu kontrol et
DEVICES=$(flutter devices | grep -i "mobile\|android" | head -1)

if [ -z "$DEVICES" ]; then
    echo "❌ Telefon bulunamadı!"
    echo ""
    echo "Yapılacaklar:"
    echo "1. Telefonu USB ile Mac'e bağlayın"
    echo "2. Telefonda: Ayarlar → Geliştirici Seçenekleri → USB Hata Ayıklama (AÇIK)"
    echo "3. İlk kez bağlıyorsanız bilgisayara güvenin"
    echo "4. Bu scripti tekrar çalıştırın"
    echo ""
    echo "Veya APK dosyasını kullanın:"
    echo "build/app/outputs/flutter-apk/app-debug.apk"
else
    echo "✅ Telefon bulundu!"
    echo ""
    echo "Uygulama telefonda başlatılıyor..."
    flutter run -d $(echo $DEVICES | awk '{print $5}')
fi







