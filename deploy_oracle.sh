#!/bin/bash

# ==========================================
# ORACLE CLOUD DEPLOY SCRIPT
# ==========================================

# Lütfen aşağıdaki bilgileri doldurun:
SERVER_IP="89.168.102.145"
SSH_USER="ubuntu"  # Oracle Linux için genelde 'opc', Ubuntu için 'ubuntu'
SSH_KEY_PATH="/Users/gokayalemdar/Downloads/ssh-key-2025-11-20.key" # Örn: ~/.ssh/oracle_key.pem

# Hedef klasör (Sunucuda)
REMOTE_DIR="/home/$SSH_USER/sicak_firsatlar_bot"

# Renkler
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Deploy işlemi başlatılıyor...${NC}"

# 1. Bağlantı Kontrolü
echo -e "${YELLOW}📡 Sunucuya bağlantı kontrol ediliyor ($SERVER_IP)...${NC}"
ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "echo '✅ Bağlantı başarılı'" 
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Sunucuya bağlanılamadı! IP adresini ve SSH anahtarını kontrol edin.${NC}"
    exit 1
fi

# 2. Uzak Klasörü Oluştur
echo -e "${YELLOW}📂 Sunucuda klasör oluşturuluyor...${NC}"
ssh -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" "mkdir -p $REMOTE_DIR"

# 3. Dosyaları Gönder
echo -e "${YELLOW}📦 Dosyalar kopyalanıyor...${NC}"
scp -i "$SSH_KEY_PATH" \
    telegram_bot.py \
    Dockerfile \
    docker-compose.yml \
    requirements.txt \
    .env \
    firebase_key.json \
    telegram_session_new.session \
    "$SSH_USER@$SERVER_IP:$REMOTE_DIR/"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Dosya kopyalama başarısız oldu!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Dosyalar başarıyla yüklendi.${NC}"

# 4. Sunucuda Kurulumu Başlat
echo -e "${YELLOW}⚙️  Sunucuda Docker kurulumu ve bot başlatma işlemi yapılıyor...${NC}"
ssh -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" << EOF
    cd $REMOTE_DIR

    # Docker yüklü mü kontrol et
    if ! command -v docker &> /dev/null; then
        echo "🐳 Docker bulunamadı, yükleniyor..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker \$USER
        echo "✅ Docker yüklendi."
    else
        echo "✅ Docker zaten yüklü."
    fi

    # Docker Compose (Plugin) yüklü mü kontrol et
    if ! docker compose version &> /dev/null; then
        echo "🐳 Docker Compose Plugin yükleniyor..."
        sudo apt-get update && sudo apt-get install -y docker-compose-plugin || sudo yum install -y docker-compose-plugin
    fi

    # Botu Başlat
    echo "🔄 Bot başlatılıyor (Rebuild)..."
    # İzin sorunları olmaması için sudo ile veya grup yetkisiyle
    if groups | grep -q "docker"; then
        docker compose up -d --build --force-recreate
    else
        # Eğer grup yetkisi hemen işlemezse sudo kullan
        sudo docker compose up -d --build --force-recreate
    fi

    echo "📊 Konteyner durumu:"
    sudo docker compose ps
EOF

echo -e "${GREEN}✅✅ DEPLOY BAŞARIYLA TAMAMLANDI! ✅✅${NC}"
echo -e "Logları izlemek için şu komutu kullanabilirsiniz:"
echo -e "${YELLOW}ssh -i $SSH_KEY_PATH $SSH_USER@$SERVER_IP 'cd $REMOTE_DIR && docker compose logs -f'${NC}"

