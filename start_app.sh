#!/bin/bash

cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"

echo "🚀 Uygulama başlatılıyor..."
echo ""

# Emülatörü kontrol et
echo "📱 Emülatör kontrol ediliyor..."
DEVICE=$(flutter devices | grep "emulator-5554" | head -1)

if [ -z "$DEVICE" ]; then
    echo "❌ Emülatör bulunamadı!"
    echo ""
    echo "Emülatörü başlatmak için:"
    echo "1. Android Studio'yu açın"
    echo "2. AVD Manager'ı açın"
    echo "3. Emülatörü başlatın"
    echo ""
    exit 1
fi

echo "✅ Emülatör bulundu: emulator-5554"
echo ""
echo "📦 Paketler kontrol ediliyor..."
flutter pub get

echo ""
echo "🔨 Uygulama başlatılıyor..."
echo "💡 İpucu: Uygulama başladıktan sonra 'r' tuşuna basarak hot reload yapabilirsiniz"
echo ""

flutter run -d emulator-5554






