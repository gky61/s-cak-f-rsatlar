# 🏷️ Kategori Çıkarma Özelliği

## ✅ Özellik Eklendi

Bot artık çekilen linklerden ve başlıklardan otomatik kategori belirliyor!

## 📋 Kategori Çıkarma Yöntemleri (Öncelik Sırası)

### 1. HTML'den Kategori Çıkarma
- **JSON-LD Schema:** `category` field'ından
- **Meta Tag'ler:** `product:category`, `og:type`, `category`
- **Breadcrumb'lar:** Sayfa breadcrumb'larından
- **Site-özel yollar:** Trendyol, Hepsiburada, N11 için özel parsing

### 2. URL'den Kategori Çıkarma
- URL path'inden kategori anahtar kelimeleri aranır
- Örnek: `/bilgisayar/...` → `bilgisayar`
- Örnek: `/telefon/...` → `mobil_cihazlar`

### 3. Başlıktan Kategori Çıkarma
- Başlıkta kategori anahtar kelimeleri aranır
- Örnek: "iPhone 15 Pro Max" → `mobil_cihazlar`
- Örnek: "PlayStation 5" → `konsol_oyun`

## 🎯 Desteklenen Kategoriler

### `bilgisayar`
- Anahtar kelimeler: bilgisayar, computer, pc, laptop, notebook, ekran kartı, gpu, işlemci, cpu, anakart, ram, ssd, hdd, depolama, güç kaynağı, psu, kasa, monitör, klavye, mouse, fare

### `mobil_cihazlar`
- Anahtar kelimeler: telefon, phone, smartphone, iphone, android, samsung, xiaomi, huawei, tablet, ipad, akıllı saat, smartwatch, bileklik, powerbank, şarj, charger, kılıf, kulaklık, headphone, earphone

### `konsol_oyun`
- Anahtar kelimeler: konsol, console, playstation, ps4, ps5, xbox, nintendo, switch, oyun, game, gamepad, joystick, direksiyon, controller

### `ev_elektronigi_yasam`
- Anahtar kelimeler: televizyon, tv, akıllı ev, smart home, robot süpürge, vacuum, aydınlatma, lighting, kişisel bakım, personal care, tıraş, hobi, hobby, drone, kamera, camera, fotoğraf, photo

### `ag_yazilim`
- Anahtar kelimeler: modem, router, mesh, ağ, network, yazılım, software, işletim sistemi, os, antivirus, antivirüs

## 📊 Çalışma Mantığı

1. **HTML çekiliyorsa:** HTML'den kategori çıkarılır
2. **HTML çekilemiyorsa:** URL'den kategori çıkarılır
3. **URL'den de bulunamazsa:** Başlıktan kategori çıkarılır
4. **Hiçbirinden bulunamazsa:** Varsayılan kategori kullanılır (`bilgisayar`)

## 🔍 Örnekler

- **"Behringer Hpx4000 Profesyonel Kulaklık"** → `mobil_cihazlar` ✅
- **"Lenovo Case 15.6 Notebook Sırt Çantası"** → `bilgisayar` ✅
- **"iPhone 15 Pro Max"** → `mobil_cihazlar` ✅
- **"PlayStation 5"** → `konsol_oyun` ✅
- **"Samsung Galaxy S24"** → `mobil_cihazlar` ✅

## ⚠️ Notlar

- Google search linkleri HTML çekilemediği için kategori çıkarılamayabilir
- Gerçek ürün linklerinde (Trendyol, Hepsiburada, N11) kategori çıkarma daha başarılı
- Başlıkta kategori anahtar kelimesi yoksa varsayılan kategori kullanılır

## 🚀 Sonraki Adımlar

Bot artık otomatik kategori belirliyor. Yeni mesajlar geldiğinde kategori otomatik atanacak ve uygulamada kategori filtresiyle görüntülenebilecek!


