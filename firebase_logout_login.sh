#!/bin/bash

# Firebase Logout ve Doğru Hesap ile Login Script

echo "🔐 Firebase Hesap Değiştirme İşlemi"
echo ""

# NVM yüklemesi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Node.js 20'ye geç
echo "📦 Node.js versiyonu kontrol ediliyor..."
nvm use 20 2>/dev/null || nvm install 20
NEW_NODE=$(node --version)
echo "✅ Aktif Node.js: $NEW_NODE"
echo ""

# Mevcut giriş durumu
echo "🔍 Mevcut Firebase giriş durumu:"
firebase login --no-localhost 2>&1 | grep -i "logged in" || echo "Giriş yapılmamış"
echo ""

# Çıkış yap
echo "🚪 Mevcut Firebase hesabından çıkış yapılıyor..."
firebase logout 2>&1 | head -5

echo ""
echo "🔐 Doğru Firebase hesabı ile giriş yapılıyor..."
echo "📧 Beklenen hesap: gokayalendar789@gmail.com"
echo ""

# Yeni giriş
firebase login

echo ""
echo "✅ Giriş işlemi tamamlandı!"
echo ""
echo "🔍 Giriş yapılan hesap:"
firebase projects:list 2>&1 | head -10

echo ""
echo "🚀 Şimdi deploy işlemini başlatabilirsiniz:"
echo "   ./deploy_functions.sh"
echo ""






