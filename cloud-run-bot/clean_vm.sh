#!/bin/bash
# ==============================================================================
# FırsatKolik GCP VM (telegram-bot-server) Performans & Temizlik Betiği
# ==============================================================================
set -e

echo "=========================================================="
echo "🧹 FırsatKolik VM Performans & Temizlik Optimizasyonu"
echo "=========================================================="

# 1. Yetim (Orphaned) İşlemci Yükü Oluşturan Süreçleri Temizleme
echo "1️⃣ Yetimsiz (Orphaned) İşlemci Yükü Oluşturan Süreçler Temizleniyor..."
sudo pkill -f "docker logs" 2>/dev/null || true
if command -v pm2 &> /dev/null; then
    pm2 kill 2>/dev/null || true
fi

# 2. Docker Konteyner Canlı Log Dosyalarını Kırpma & Rotasyon Ayarı
echo "2️⃣ Docker Konteyner Log Boyutları Kırpılıyor..."
sudo find /var/lib/docker/containers/ -type f -name "*-json.log" -exec truncate -s 0 {} + 2>/dev/null || true

if [ ! -f /etc/docker/daemon.json ]; then
    echo "  ⚙️ Docker daemon log rotasyon kuralı ekleniyor (max 20m x 3)..."
    cat << 'DOCKERCONF' | sudo tee /etc/docker/daemon.json > /dev/null
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "20m",
    "max-file": "3"
  }
}
DOCKERCONF
    sudo systemctl reload docker 2>/dev/null || true
fi

# 3. 1GB Swap (Sanal Bellek) Korumasını Kontrol Etme
echo "3️⃣ 1GB Swap (Sanal Bellek) Koruması Kontrol Ediliyor..."
if ! grep -q '/swapfile' /proc/swaps 2>/dev/null; then
    if [ ! -f /swapfile ]; then
        echo "  ➕ /swapfile oluşturuluyor (1GB)..."
        sudo fallocate -l 1G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
    fi
    sudo /sbin/swapon /swapfile || sudo swapon /swapfile || true
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab > /dev/null
    fi
    echo "  ✅ 1GB Swap başarıyla kuruldu ve aktifleştirildi!"
else
    echo "  ✅ 1GB Swap koruması aktif."
fi

# 4. Docker Eski Derleme Önbelleği (Build Cache) ve Atık İmaj Temizliği
echo "4️⃣ Docker Derleme Önbelleği ve Atık İmajlar Temizleniyor..."
sudo docker builder prune -af --filter "until=24h"
sudo docker image prune -a -f --filter "until=24h" || true
sudo docker container prune -f
sudo docker volume prune -f

# 5. Paket Yöneticisi (APT) Önbellek Temizliği
echo "5️⃣ Paket Yöneticisi (APT) Önbelleği Temizleniyor..."
sudo apt-get clean
sudo apt-get autoremove -y

# 6. Sistem Logları ve Journal Vakumlama
echo "6️⃣ Sistem Logları ve Journal Temizleniyor..."
sudo journalctl --vacuum-size=30M
sudo rm -rf /var/log/*.gz /var/log/*.1 /var/log/*.[0-9] 2>/dev/null || true

# 7. Geçici Test ve Arşiv Dosyaları
echo "7️⃣ Geçici /tmp Test ve Arşiv Dosyaları Temizleniyor..."
sudo rm -rf /tmp/test_* /tmp/inspect_* /tmp/yandex_* /tmp/getir_* /tmp/google_* /tmp/check_* /tmp/pagespeed* /tmp/bot_code* 2>/dev/null || true

# 8. Çekirdek (Sysctl) Performans Ayarları & RAM Önbellek Sıfırlama
echo "8️⃣ Kernel Sysctl Performans Ayarları & RAM Önbelleği Sıfırlanıyor..."
sudo sysctl -w vm.swappiness=10 > /dev/null 2>&1 || true
sudo sysctl -w vm.vfs_cache_pressure=50 > /dev/null 2>&1 || true
sudo sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

echo "=========================================================="
echo "✅ Performans & Temizlik Optimizasyonu Tamamlandı!"
echo "=========================================================="
echo "💾 DİSK KULLANIMI:"
df -h /
echo ""
echo "🧠 RAM VE SWAP KULLANIMI:"
free -h
echo ""
echo "🐳 DOCKER SİSTEM DURUMU:"
sudo docker system df
echo ""
echo "📦 ÇALIŞAN KONTEYNERLER (dev-bot & prod-bot):"
sudo docker ps -a
