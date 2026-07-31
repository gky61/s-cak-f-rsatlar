#!/bin/bash
# ==============================================================================
# FırsatKolik GCP VM (telegram-bot-server) Tam Performans & Temizlik Betiği
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

# 2. Kalıcı Kernel (Sysctl) Performans Optimizasyonu (RAM, Swap & Network Queue)
echo "2️⃣ Kalıcı Kernel (Sysctl) İnce Ayarları Yapılandırılıyor..."
cat << 'SYSCTL_EOF' | sudo tee /etc/sysctl.d/99-firsatkolik-opt.conf > /dev/null
# FırsatKolik Free-Tier VM Performans & Bellek Optimizasyonu
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.somaxconn=1024
SYSCTL_EOF
sudo /sbin/sysctl -p /etc/sysctl.d/99-firsatkolik-opt.conf > /dev/null 2>&1 || sudo sysctl --system > /dev/null 2>&1 || true
echo "  ✅ Kernel ayarları uygulandı (Swappiness: 10, VFS Cache: 50, Somaxconn: 1024)."

# 3. Docker Daemon Log Rotasyon Yapılandırması ve Canlı Log Kırpma
echo "3️⃣ Docker Log Yapılandırması & Log Kırpma İşlemi..."
sudo find /var/lib/docker/containers/ -type f -name "*-json.log" -exec truncate -s 0 {} + 2>/dev/null || true

if [ ! -f /etc/docker/daemon.json ]; then
    echo "  ⚙️ Docker daemon.json oluşturuluyor (Max log: 20MB x 3)..."
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

# 4. Gereksiz Arka Plan Servislerinin Durdurulması (Exim4 Mail Daemon)
echo "4️⃣ Gereksiz Arka Plan Servisleri Kontrol Ediliyor..."
if systemctl is-active --quiet exim4 2>/dev/null; then
    sudo systemctl stop exim4 || true
    sudo systemctl disable exim4 || true
    echo "  ✅ Gereksiz Exim4 mail servisi durduruldu ve devre dışı bırakıldı."
else
    echo "  ✅ Arka planda çalışan gereksiz mail servisi yok."
fi

# 5. 1GB Swap (Sanal Bellek) Korumasını Kontrol Etme
echo "5️⃣ 1GB Swap (Sanal Bellek) Koruması Kontrol Ediliyor..."
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

# 6. Docker Eski Derleme Önbelleği (Build Cache) ve Atık İmaj Temizliği
echo "6️⃣ Docker Derleme Önbelleği ve Atık İmajlar Temizleniyor..."
sudo docker builder prune -af --filter "until=24h"
sudo docker image prune -a -f --filter "until=24h" || true
sudo docker container prune -f
sudo docker volume prune -f

# 7. Paket Yöneticisi (APT) Önbellek Temizliği
echo "7️⃣ Paket Yöneticisi (APT) Önbelleği Temizleniyor..."
sudo apt-get clean
sudo apt-get autoremove -y

# 8. Sistem Logları ve Journal Vakumlama
echo "8️⃣ Sistem Logları ve Journal Temizleniyor..."
sudo journalctl --vacuum-size=30M
sudo rm -rf /var/log/*.gz /var/log/*.1 /var/log/*.[0-9] 2>/dev/null || true

# 9. Geçici Test ve Arşiv Dosyaları
echo "9️⃣ Geçici /tmp Test ve Arşiv Dosyaları Temizleniyor..."
sudo rm -rf /tmp/test_* /tmp/inspect_* /tmp/yandex_* /tmp/getir_* /tmp/google_* /tmp/check_* /tmp/pagespeed* /tmp/bot_code* 2>/dev/null || true

# 10. RAM Önbelleği Sıfırlama (PageCache Flush)
echo "🔟 RAM Önbelleği Sıfırlanıyor (PageCache Flush)..."
sudo sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

echo "=========================================================="
echo "✅ Tam Performans & Temizlik Optimizasyonu Tamamlandı!"
echo "=========================================================="
echo "💾 DİSK KULLANIMI:"
df -h /
echo ""
echo "🧠 RAM VE SWAP KULLANIMI:"
free -h
echo ""
echo "⚡ KERNEL VE İŞLETİM SİSTEMİ PARAMETRELERİ:"
sudo /sbin/sysctl vm.swappiness vm.vfs_cache_pressure net.core.somaxconn 2>/dev/null || sysctl vm.swappiness vm.vfs_cache_pressure net.core.somaxconn
echo ""
echo "🐳 DOCKER SİSTEM DURUMU:"
sudo docker system df
echo ""
echo "📦 ÇALIŞAN KONTEYNERLER (dev-bot & prod-bot):"
sudo docker ps -a
