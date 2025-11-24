# Python 3.9 slim imajını kullan (hafif ve hızlı)
FROM python:3.9-slim

# Çalışma dizinini ayarla
WORKDIR /app

# Gerekli sistem paketlerini yükle (gcc vs gerekirse)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Bağımlılıkları kopyala ve yükle
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama kodlarını kopyala
COPY telegram_bot.py .
COPY firebase_key.json .
COPY .env .

# Logların anlık akması için
ENV PYTHONUNBUFFERED=1

# Botu başlat
CMD ["python", "telegram_bot.py"]

