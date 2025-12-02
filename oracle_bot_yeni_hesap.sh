#!/bin/bash

# Oracle Sunucuda Yeni Hesap ile Bot Başlatma
# Bu script Oracle sunucusuna SSH ile bağlanıp botu interaktif modda başlatır

echo "🚀 Oracle sunucusuna bağlanılıyor..."
echo "📱 Yeni Telegram hesabı ile giriş yapılacak"
echo ""
echo "⚠️  ÖNEMLİ: Bot başladığında telefon numaranızı ve doğrulama kodunu girmeniz gerekecek!"
echo ""

ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 << 'EOF'
    cd ~/sicak-firsatlar
    
    # Eski bot process'lerini durdur
    pkill -f telegram_bot.py || true
    sleep 2
    
    # Session dosyalarını sil (yeni giriş için)
    rm -f telegram_session*.session
    echo "✅ Eski session dosyaları silindi"
    
    # Virtual environment'ı aktifleştir
    source venv/bin/activate
    
    echo ""
    echo "=========================================="
    echo "🤖 Bot başlatılıyor..."
    echo "📱 Telefon numaranızı girmeniz gerekecek"
    echo "=========================================="
    echo ""
    
    # Botu interaktif modda başlat
    python telegram_bot.py
EOF

echo ""
echo "✅ Bot başlatıldı (veya hata oluştu)"
echo "📋 Logları kontrol etmek için:"
echo "   ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 'cd ~/sicak-firsatlar && tail -f bot.log'"

