#!/bin/bash
echo "🚀 FırsatKolik PROD Release AAB Derlemesi Başlıyor..."
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
echo "✅ Derleme Tamamlandı! Dosya konumu: build/app/outputs/bundle/prodRelease/app-prod-release.aab"
