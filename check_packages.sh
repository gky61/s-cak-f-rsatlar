#!/bin/bash
# Oracle Cloud VM'de paketleri kontrol et

echo "🔍 Paket kontrolü yapılıyor..."
echo ""

# google-generativeai kontrolü
echo "📦 google-generativeai kontrolü:"
pip3 list | grep -i "google-generativeai" || echo "❌ google-generativeai YÜKLÜ DEĞİL!"

echo ""

# Pillow kontrolü
echo "📦 Pillow kontrolü:"
pip3 list | grep -i "pillow" || echo "❌ Pillow YÜKLÜ DEĞİL!"

echo ""
echo "✅ Kontrol tamamlandı!"









