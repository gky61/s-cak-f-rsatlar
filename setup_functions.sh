#!/bin/bash

# Firebase Cloud Functions Kurulum Scripti
# Bu script Functions klasöründeki NPM paketlerini yükler

echo "🔥 Firebase Cloud Functions Kurulumu Başlatılıyor..."
echo ""

# Node.js versiyonunu kontrol et
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
echo "📦 Node.js versiyonu: $(node --version)"

if [ "$NODE_VERSION" -lt 20 ]; then
    echo "⚠️  UYARI: Node.js 20 veya üzeri gereklidir!"
    echo "📝 Lütfen Node.js'i güncelleyin:"
    echo "   - nvm install 20 && nvm use 20"
    echo "   - veya https://nodejs.org/ adresinden indirin"
    echo ""
    read -p "Devam etmek istiyor musunuz? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Firebase CLI kontrolü
if ! command -v firebase &> /dev/null; then
    echo "⚠️  Firebase CLI bulunamadı!"
    echo "📝 Firebase CLI'yi yüklemek için:"
    echo "   npm install -g firebase-tools"
    echo ""
    read -p "Devam etmek istiyor musunuz? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Firebase CLI: $(firebase --version 2>/dev/null || echo 'Kurulu değil')"
fi

# Functions klasörüne git
cd functions || exit 1

echo ""
echo "📦 NPM paketleri yükleniyor..."
npm install

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Kurulum tamamlandı!"
    echo ""
    echo "📝 Sonraki adımlar:"
    echo "   1. firebase login (eğer giriş yapmadıysanız)"
    echo "   2. firebase deploy --only functions"
    echo ""
else
    echo ""
    echo "❌ Kurulum başarısız!"
    exit 1
fi






