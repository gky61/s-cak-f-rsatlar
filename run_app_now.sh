#!/bin/bash

cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"

echo "🚀 Uygulama başlatılıyor..."
echo ""

# Paketleri kontrol et
echo "📦 Paketler kontrol ediliyor..."
flutter pub get

echo ""
echo "🔨 Uygulama başlatılıyor (Android Emülatör)..."
echo ""

# Android emülatörde çalıştır
flutter run -d emulator-5554





