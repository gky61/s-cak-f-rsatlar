# 🖼️ Görsel Çekme Mantığı

Bot görseli **2 farklı kaynaktan** çekmeye çalışıyor, öncelik sırasına göre:

## 📊 Görsel Çekme Öncelik Sırası

### 1️⃣ Öncelik: Telegram Media'dan Çek

**Ne zaman çalışır:**
- Telegram mesajında görsel eklentisi varsa (`message.media`)
- Veya mesajda `blob:` URL'i tespit edilirse

**Nasıl çalışır:**
1. Telegram'dan görseli indirir (`download_media`)
2. Görseli Firebase Storage'a yükler
3. Public URL oluşturur: `https://storage.googleapis.com/sicak-firsatlar-e6eae.appspot.com/telegram/...`

**Kod:**
```python
# telegram_bot.py satır 96-139
async def fetch_image_from_telegram(...)
```

**Sorun:**
- ❌ Firebase Storage bucket bulunamıyor (404 hatası)
- Bu yüzden Telegram media'dan görsel çekilemiyor

---

### 2️⃣ Öncelik: Linkten Çek (HTML Parse)

**Ne zaman çalışır:**
- Telegram media'dan görsel çekilemediyse
- Ve deal link'i varsa

**Nasıl çalışır:**
1. Deal link'inden HTML'i çeker (`fetch_link_data`)
2. HTML'i parse eder (BeautifulSoup)
3. Görseli **7 farklı yöntemle** arar:

#### Yöntem 1: JSON-LD Schema
```html
<script type="application/ld+json">
{
  "image": "https://example.com/image.jpg"
}
</script>
```

#### Yöntem 2: Open Graph
```html
<meta property="og:image" content="https://example.com/image.jpg">
```

#### Yöntem 3: Twitter Card
```html
<meta name="twitter:image" content="https://example.com/image.jpg">
```

#### Yöntem 4: Trendyol Özel
```html
<img data-image="https://example.com/image.jpg">
```

#### Yöntem 5: Itemprop
```html
<img itemprop="image" src="https://example.com/image.jpg">
```

#### Yöntem 6: Product Image Class'ları
```html
<img class="product-image" src="https://example.com/image.jpg">
```

#### Yöntem 7: Genel img Tag'leri
```html
<img src="https://example.com/image.jpg">
```

**Kod:**
```python
# telegram_bot.py satır 168-220
def extract_image_from_html(...)
```

**Sorun:**
- ⚠️ `app.hb.biz` linkleri için HTML çekilemiyor
- Bu linkler muhtemelen redirect veya özel bir yapı kullanıyor

---

## 🔍 Mevcut Durum

### Son Test Sonuçları:

**Deal 1:**
- Link: `https://app.hb.biz/XqkvHerCEkpx`
- Telegram Media: ✅ Var
- Telegram'dan Çekme: ❌ Firebase Storage hatası
- Linkten Çekme: ❌ HTML çekilemedi
- Sonuç: Görsel YOK

**Deal 2:**
- Link: `https://app.hb.biz/knNotypMwzM4`
- Telegram Media: ✅ Var
- Telegram'dan Çekme: ❌ Firebase Storage hatası
- Linkten Çekme: ❌ HTML çekilemedi
- Sonuç: Görsel YOK

---

## 🛠️ Çözüm Önerileri

### 1. Firebase Storage Bucket Sorunu

**Sorun:** Bucket bulunamıyor (404)

**Çözüm:**
- Firebase Console'dan Storage'ı aktif et
- Bucket adını kontrol et: `sicak-firsatlar-e6eae.appspot.com`
- Veya bucket'ı oluştur

### 2. app.hb.biz Linkleri

**Sorun:** HTML çekilemiyor

**Çözüm:**
- Bu linkler muhtemelen redirect yapıyor
- Redirect'i takip et
- Veya farklı user-agent/header'lar dene
- Veya JavaScript render gerekiyor olabilir

### 3. Alternatif: Flutter Uygulamasında Çekme

**Mevcut Durum:**
- Flutter uygulamasında `LinkPreviewService` var
- `DealCard` widget'ı görsel yoksa linkten çekmeyi deniyor
- Bu yüzden bot görsel çekmese bile, uygulama çekebilir

---

## 📝 Özet

**Görsel Çekme Kaynakları:**
1. ✅ Telegram Media (öncelikli) - Firebase Storage hatası var
2. ✅ Link HTML'i (fallback) - app.hb.biz linkleri için çalışmıyor
3. ✅ Flutter Uygulaması (son çare) - LinkPreviewService ile

**Öneri:**
- Firebase Storage bucket sorununu çöz
- app.hb.biz linkleri için redirect takibi ekle
- Veya Flutter uygulamasındaki görsel çekme mekanizmasına güven





