#!/bin/bash
# AdMob test reklamlarının log'larını görmek için kullanın
# Kullanım: ./test_reklam_loglari.sh

echo "🔍 AdMob reklam log'ları dinleniyor..."
echo "📱 Telefonu USB ile bağlayın ve uygulamayı açın"
echo ""
echo "Çıkmak için Ctrl+C basın"
echo ""

adb logcat | grep -E "(AdMob|Reklam|Banner|Test|✅|❌|🔄|flutter.*AdMob|flutter.*Banner|flutter.*Reklam)"




