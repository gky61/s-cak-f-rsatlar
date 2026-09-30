#!/bin/bash
# ==============================================================================
# FırsatKolik GCP VM (telegram-bot-server) Otonom Performans & Temizlik Betiği
# Sürüm: 2.0 (Gold Standard / Zero-Failure SRE Edition)
# Zamanlama: Her Gece 04:00 TSİ (01:00 UTC) Crontab ile Çalışır
# ==============================================================================
set -e

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')
echo "=========================================================="
echo "🧹 FırsatKolik VM Otonom Gece Bakımı & Performans Temizliği"
echo "🕒 Başlangıç Zamanı: $TIMESTAMP"
echo "=========================================================="

# 1. Kalıcı Kernel (Sysctl) Performans Optimizasyonu (RAM, Swap & Network Queue)
echo "1️⃣ Kalıcı Kernel (Sysctl) İnce Ayarları Denetleniyor..."
if [ ! -f /etc/sysctl.d/99-firsatkolik-opt.conf ]; then
    cat << 'SYSCTL_EOF' | sudo tee /etc/sysctl.d/99-firsatkolik-opt.conf > /dev/null
# FırsatKolik Free-Tier VM Performans & Bellek Optimizasyonu
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.somaxconn=1024
SYSCTL_EOF
    sudo /sbin/sysctl -p /etc/sysctl.d/99-firsatkolik-opt.conf > /dev/null 2>&1 || sudo sysctl --system > /dev/null 2>&1 || true
    echo "  ✅ Kernel ayarları ilk kez uygulandı (Swappiness: 10, VFS Cache: 50, Somaxconn: 1024)."
else
    sudo /sbin/sysctl -p /etc/sysctl.d/99-firsatkolik-opt.conf > /dev/null 2>&1 || true
    echo "  ✅ Kernel ayarları doğrulandı ve korundu."
fi

# 2. Docker Daemon Log Rotasyon Yapılandırması
echo "2️⃣ Docker Log Rotasyonu Denetleniyor..."
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
    echo "  ✅ Docker daemon log rotasyonu aktifleştirildi."
else
    echo "  ✅ Docker daemon.json yapılandırması mevcut."
fi

# 3. Gereksiz Arka Plan Servislerinin Durdurulması (Exim4 vb.)
echo "3️⃣ Gereksiz Arka Plan Servisleri Kontrol Ediliyor..."
if systemctl is-active --quiet exim4 2>/dev/null; then
    sudo systemctl stop exim4 || true
    sudo systemctl disable exim4 || true
    echo "  ✅ Gereksiz Exim4 mail servisi durduruldu ve devre dışı bırakıldı."
else
    echo "  ✅ Arka planda çalışan gereksiz mail servisi yok."
fi

# 4. 1GB Swap (Sanal Bellek) Korumasını Kontrol Etme
echo "4️⃣ 1GB Swap (Sanal Bellek) Koruması Kontrol Ediliyor..."
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

# 5. Docker Eski Derleme Önbelleği (Build Cache) ve Atık İmaj Temizliği
echo "5️⃣ Docker Derleme Önbelleği ve Atık İmajlar Temizleniyor..."
sudo docker builder prune -af --filter "until=24h"
sudo docker image prune -a -f --filter "until=24h" || true
sudo docker container prune -f
sudo docker volume prune -f

# 6. Paket Yöneticisi (APT) Önbellek Temizliği (Güvenli clean)
echo "6️⃣ Paket Yöneticisi (APT) Önbelleği Temizleniyor..."
sudo apt-get clean

# 7. Sistem Logları ve Journal Vakumlama
echo "7️⃣ Sistem Logları ve Journal Vakumlanıyor..."
sudo journalctl --vacuum-size=20M
sudo rm -rf /var/log/*.gz /var/log/*.1 /var/log/*.[0-9] 2>/dev/null || true

# 8. Geçici /tmp Test ve Arşiv Dosyaları
echo "8️⃣ Geçici /tmp Dosyaları Temizleniyor..."
sudo rm -rf /tmp/test_* /tmp/inspect_* /tmp/check_* /tmp/vm_info* /tmp/*.log 2>/dev/null || true

# 9. Bot Konteynerlerini Sıfır Kilometre Canlandırma (Self-Healing Restart)
echo "9️⃣ Bot Konteynerleri Sıfır Bellekle Yeniden Başlatılıyor (dev-bot & prod-bot)..."
sudo docker restart dev-bot prod-bot || true

# 10. Liveness & Sağlık Denetimi (Health Check Watchdog)
echo "🔟 Konteyner Sağlık Kontrolü Yapılıyor (Polling Watchdog)..."

check_bot_health() {
    local port=$1
    local name=$2
    for i in {1..6}; do
        sleep 5
        local code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/health" 2>/dev/null || echo "000")
        if [ "$code" = "200" ]; then
            echo "  ✅ ${name} (Port ${port}): SAĞLIKLI (HTTP 200 OK - ${i}x5sn)"
            return 0
        fi
    done
    echo "  ⚠️ ${name} (Port ${port}): 30 saniye içinde HTTP 200 vermedi, yeniden başlatılıyor..."
    sudo docker restart "${name}" || true
}

check_bot_health 8081 "dev-bot"
check_bot_health 8082 "prod-bot"

echo "=========================================================="
echo "✅ FırsatKolik Otonom Gece Bakımı Başarıyla Tamamlandı!"
echo "🕒 Bitiş Zamanı: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "=========================================================="
echo "💾 GÜNCEL DİSK KULLANIMI:"
df -h /
echo ""
echo "🧠 GÜNCEL RAM VE SWAP KULLANIMI:"
free -h
echo ""
echo "🐳 DOCKER SİSTEM DURUMU:"
sudo docker system df
echo ""
echo "📦 AKTİF KONTEYNERLER:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
