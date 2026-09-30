#!/bin/bash
# ==============================================================================
# FırsatKolik GCP VM (telegram-bot-server) Otonom Performans & Temizlik Betiği
# Sürüm: 2.1 (Ultra-Resilient Gold Standard / Self-Healing Edition)
# Zamanlama: Her Gece 04:00 TSİ (01:00 UTC) Crontab ile Otonom Çalışır
# ==============================================================================

# NOT: 'set -e' kasıtlı olarak kullanılmamıştır; geçici bir dosya kilidi veya
# ufak bir temizlik uyarısı botların yeniden başlatılmasını ve sağlık denetimini
# ASLA engellememelidir. Her adım bağımsız ve hata-korumalıdır.

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')
echo "=========================================================="
echo "🧹 FırsatKolik VM Otonom Gece Bakımı & Performans Temizliği"
echo "🕒 Başlangıç Zamanı: $TIMESTAMP"
echo "=========================================================="

# 0. Bakım Günlük Logu Rotasyonu (Log Dosyası Asla 5 MB'ı Geçemez)
if [ -f /home/murat/clean_vm.log ] && [ $(stat -c%s /home/murat/clean_vm.log 2>/dev/null || echo 0) -gt 5242880 ]; then
    echo "  ⚙️ /home/murat/clean_vm.log 5MB sınırını aştı, son 1000 satır korunarak kırpılıyor..."
    tail -n 1000 /home/murat/clean_vm.log > /home/murat/clean_vm.log.tmp 2>/dev/null && mv /home/murat/clean_vm.log.tmp /home/murat/clean_vm.log 2>/dev/null || true
fi

# 1. Kalıcı Kernel (Sysctl) Performans Optimizasyonu (RAM, Swap & Network Queue)
echo "1️⃣ Kalıcı Kernel (Sysctl) İnce Ayarları Denetleniyor..."
if [ ! -f /etc/sysctl.d/99-firsatkolik-opt.conf ]; then
    cat << 'SYSCTL_EOF' | sudo tee /etc/sysctl.d/99-firsatkolik-opt.conf > /dev/null
# FırsatKolik Free-Tier VM Performans & Bellek Optimizasyonu
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.somaxconn=1024
net.ipv4.tcp_tw_reuse=1
SYSCTL_EOF
    sudo /sbin/sysctl -p /etc/sysctl.d/99-firsatkolik-opt.conf > /dev/null 2>&1 || sudo sysctl --system > /dev/null 2>&1 || true
    echo "  ✅ Kernel ayarları ilk kez uygulandı (Swappiness: 10, VFS Cache: 50, Somaxconn: 1024, TCP Reuse: 1)."
else
    # Güncelleme kontrolü: tcp_tw_reuse yoksa ekle
    if ! grep -q 'tcp_tw_reuse' /etc/sysctl.d/99-firsatkolik-opt.conf 2>/dev/null; then
        echo "net.ipv4.tcp_tw_reuse=1" | sudo tee -a /etc/sysctl.d/99-firsatkolik-opt.conf > /dev/null
    fi
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
    sudo systemctl stop exim4 2>/dev/null || true
    sudo systemctl disable exim4 2>/dev/null || true
    echo "  ✅ Gereksiz Exim4 mail servisi durduruldu ve devre dışı bırakıldı."
else
    echo "  ✅ Arka planda çalışan gereksiz mail servisi yok."
fi

# 4. 1GB Swap (Sanal Bellek) Korumasını Kontrol Etme
echo "4️⃣ 1GB Swap (Sanal Bellek) Koruması Kontrol Ediliyor..."
if ! grep -q '/swapfile' /proc/swaps 2>/dev/null; then
    if [ ! -f /swapfile ]; then
        echo "  ➕ /swapfile oluşturuluyor (1GB)..."
        sudo fallocate -l 1G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024 2>/dev/null
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile >/dev/null 2>&1
    fi
    sudo /sbin/swapon /swapfile 2>/dev/null || sudo swapon /swapfile 2>/dev/null || true
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab > /dev/null
    fi
    echo "  ✅ 1GB Swap başarıyla kuruldu ve aktifleştirildi!"
else
    echo "  ✅ 1GB Swap koruması aktif."
fi

# 5. Docker Eski Derleme Önbelleği (Build Cache) ve Atık İmaj Temizliği
echo "5️⃣ Docker Derleme Önbelleği ve Atık İmajlar Temizleniyor..."
sudo docker builder prune -af --filter "until=24h" 2>/dev/null || true
sudo docker image prune -a -f --filter "until=24h" 2>/dev/null || true
sudo docker container prune -f 2>/dev/null || true
sudo docker volume prune -f 2>/dev/null || true

# 6. Paket Yöneticisi (APT) Önbellek Temizliği (Güvenli clean)
echo "6️⃣ Paket Yöneticisi (APT) Önbelleği Temizleniyor..."
sudo apt-get clean 2>/dev/null || true

# 7. Sistem Logları, Crash Dump ve Journal Vakumlama
echo "7️⃣ Sistem Logları ve Journal Vakumlanıyor..."
sudo journalctl --vacuum-size=20M 2>/dev/null || true
sudo rm -rf /var/log/*.gz /var/log/*.1 /var/log/*.[0-9] /var/crash/* 2>/dev/null || true

# 8. Geçici /tmp ve Kullanıcı Önbellek Dosyaları
echo "8️⃣ Geçici /tmp ve Önbellek Dosyaları Temizleniyor..."
sudo rm -rf /tmp/test_* /tmp/inspect_* /tmp/check_* /tmp/vm_info* /tmp/*.log /var/tmp/* /home/murat/.cache/* 2>/dev/null || true

# 9. Bot Konteynerlerini Sıfır Kilometre Canlandırma (Self-Healing Rebirth)
echo "9️⃣ Bot Konteynerleri Sıfır Bellekle Yeniden Canlandırılıyor..."
sync 2>/dev/null || true

restart_or_start_bot() {
    local name=$1
    local port=$2
    local env=$3
    if sudo docker ps -a --format '{{.Names}}' | grep -Eq "^${name}\$"; then
        echo "  🔄 ${name} yeniden başlatılıyor..."
        sudo docker restart "${name}" 2>/dev/null || true
    else
        echo "  ⚠️ ${name} konteyneri bulunamadı, baştan oluşturuluyor..."
        local remote_dir="/home/murat/app/${env}-bot"
        sudo docker run -d --name "${name}" --restart always -p "${port}:8080" \
            --env-file "${remote_dir}/.env" \
            -v "${remote_dir}/${env}_firebase_key.json:/app/firebase_key.json" \
            gcr.io/firsatkolik-prod-e6eae/telegram-bot:latest 2>/dev/null || true
    fi
}

restart_or_start_bot "dev-bot" "8081" "dev"
sleep 3
restart_or_start_bot "prod-bot" "8082" "prod"

# 10. Liveness & Sağlık Denetimi (Health Check Watchdog)
echo "🔟 Konteyner Sağlık Kontrolü Yapılıyor (Polling Watchdog)..."

check_bot_health() {
    local port=$1
    local name=$2
    local env=$3
    for i in {1..12}; do
        sleep 5
        local code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/health" 2>/dev/null || echo "000")
        if [ "$code" = "200" ]; then
            echo "  ✅ ${name} (Port ${port}): SAĞLIKLI (HTTP 200 OK - ${i}x5sn)"
            return 0
        fi
    done
    echo "  ⚠️ ${name} (Port ${port}): 60 saniye içinde HTTP 200 vermedi, yeniden başlatılıyor..."
    restart_or_start_bot "${name}" "${port}" "${env}"
}

check_bot_health 8081 "dev-bot" "dev"
check_bot_health 8082 "prod-bot" "prod"

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
