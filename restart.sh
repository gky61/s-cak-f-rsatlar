#!/bin/bash

echo "🛑 Flutter süreçlerini durduruyorum..."
pkill -9 -f "flutter" 2>/dev/null || true

echo "🧹 Temizlik yapıyorum..."
cd "$(dirname "$0")"
flutter clean > /dev/null 2>&1

echo "📦 Bağımlılıkları yüklüyorum..."
flutter pub get > /dev/null 2>&1

echo "🚀 Uygulamayı başlatıyorum..."
flutter run -d emulator-5554







