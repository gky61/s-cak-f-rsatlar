#!/bin/bash

# Firebase Login Script
# Bu script Firebase'e giriş yapmanıza yardımcı olur

echo "🔥 Firebase Giriş İşlemi Başlatılıyor..."
echo ""

# Proje dizinine git
cd "$(dirname "$0")/.."

# NVM yüklemesi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Node.js 20'ye geç (Firebase CLI için gerekli)
echo "📦 Node.js versiyonu kontrol ediliyor..."
CURRENT_NODE=$(node --version 2>/dev/null || echo "none")
echo "   Mevcut: $CURRENT_NODE"

# Node.js 20 yüklü mü kontrol et
if [ ! -d "$NVM_DIR/versions/node/v20"* ]; then
    echo "📥 Node.js v20 yükleniyor..."
    nvm install 20
fi

echo "🔄 Node.js v20'ye geçiliyor..."
nvm use 20

NEW_NODE=$(node --version)
echo "✅ Aktif Node.js: $NEW_NODE"
echo ""

# Firebase login
echo "🌐 Firebase'e giriş yapılıyor..."
echo "📝 Lütfen tarayıcıda açılacak sayfada Google hesabınızla giriş yapın."
echo ""

firebase login

echo ""
echo "✅ Firebase giriş işlemi tamamlandı."
echo ""
echo "🚀 Şimdi deploy işlemini başlatabilirsiniz:"
echo "   ./scripts/deploy_functions.sh"
echo ""

