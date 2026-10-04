#!/bin/bash

# Firebase Functions Deploy Script
# Bu script Firebase Functions'ı deploy eder

# P1-08 (R-QA-06): Açık hedef proje ve ortam kontrolü
TARGET_ENV=$1
if [ -z "$TARGET_ENV" ]; then
    echo "❌ HATA (P1-08 / R-QA-06): Hedef ortam belirtilmelidir!"
    echo "   Kullanım: ./deploy_functions.sh <dev|prod>"
    exit 1
fi

if [ "$TARGET_ENV" = "prod" ]; then
    echo "⚠️  DİKKAT: CANLI PRODÜKSİYON ORTAMI SEÇİLDİ (firsatkolik-prod-e6eae)!"
    read -p "Canlı ortama Firebase Functions deploy etmek istediğinizden emin misiniz? (e/H): " confirm
    if [ "$confirm" != "e" ] && [ "$confirm" != "E" ]; then
        echo "❌ Dağıtım kullanıcı tarafından iptal edildi."
        exit 1
    fi
    PROJECT_ID="firsatkolik-prod-e6eae"
elif [ "$TARGET_ENV" = "dev" ]; then
    PROJECT_ID="sicak-firsatlar-e6eae"
else
    echo "❌ HATA: Geçersiz ortam: '$TARGET_ENV'. Yalnızca 'dev' veya 'prod' kabul edilir."
    exit 1
fi

# NVM yüklemesi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Proje dizinine git
cd "$(dirname "$0")/.."

# Node.js 20'ye geç (Firebase CLI için gerekli)
echo "🔍 Node.js versiyonu kontrol ediliyor..."
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
echo "🔍 Firebase giriş durumu kontrol ediliyor..."
if ! firebase projects:list &>/dev/null; then
    echo "❌ Firebase'e giriş yapılmamış."
    echo "📝 Lütfen önce şu komutu çalıştırın:"
    echo "   firebase login"
    exit 1
fi

echo "✅ Firebase'e giriş yapılmış."

echo ""
echo "📦 Functions bağımlılıkları kontrol ediliyor..."
cd functions
if [ ! -d "node_modules" ]; then
    echo "📥 node_modules bulunamadı, npm install çalıştırılıyor..."
    npm install
else
    echo "✅ node_modules mevcut."
fi

cd ..

echo ""
echo "🚀 Firebase Functions deploy ediliyor ($TARGET_ENV -> $PROJECT_ID)..."
firebase deploy --only functions --project "$PROJECT_ID"

echo ""
echo "✅ Deploy işlemi tamamlandı!"

