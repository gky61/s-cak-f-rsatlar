# 🤖 Gemini API Test Rehberi

## 📍 Console Loglarını Görmek İçin

### Yöntem 1: Terminal'den Çalıştırma (Önerilen)

1. **Terminal'i açın** (Mac: Terminal.app, Windows: PowerShell veya CMD)

2. **Proje klasörüne gidin:**
```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
```

3. **Flutter uygulamasını çalıştırın:**
```bash
flutter run
```

4. **Console loglarını göreceksiniz:**
   - Uygulama başladığında: `🤖 Gemini API bağlantısı test ediliyor...`
   - Başarılı ise: `✅ Gemini API çalışıyor!`
   - Hata varsa: `⚠️ Gemini API bağlantı hatası` + detaylı hata mesajı

### Yöntem 2: VS Code / Android Studio

1. **VS Code'da:**
   - Terminal panelini açın (Ctrl+` veya Cmd+`)
   - `flutter run` komutunu çalıştırın
   - Loglar terminal panelinde görünecek

2. **Android Studio'da:**
   - Alt kısımdaki "Run" sekmesini açın
   - Loglar otomatik görünecek

## 🧪 Gemini API'yi Test Etme

### Otomatik Test (Uygulama Başlatıldığında)

Uygulama her başlatıldığında otomatik olarak Gemini API test edilir:
- Debug modda çalışıyorsanız console'da sonuçları göreceksiniz
- Test arka planda çalışır, uygulamayı yavaşlatmaz

### Manuel Test (Fırsat Paylaşım Ekranında)

1. **Uygulamayı açın**
2. **"Fırsat Paylaş" butonuna tıklayın** (sağ alttaki + butonu)
3. **Ürün Linki alanına bir URL girin**, örneğin:
   ```
   https://www.trendyol.com/urun/...
   https://www.hepsiburada.com/urun/...
   https://www.n11.com/urun/...
   ```

4. **1.5 saniye bekleyin** - AI otomatik analiz yapacak

5. **Sonuçları kontrol edin:**
   - ✅ **Başarılı ise:** Yeşil SnackBar görünecek: "🤖 AI ile otomatik tespit: [kategori] kategorisi"
   - ❌ **Hata varsa:** Turuncu/Kırmızı SnackBar görünecek: "⚠️ AI analizi başarısız: [hata mesajı]"

6. **Console loglarını kontrol edin:**
   - Terminal'de detaylı loglar görünecek
   - Hata varsa tam hata mesajını göreceksiniz

## 🔍 Console Loglarında Ne Aranmalı?

### Başarılı Loglar:
```
🤖 Gemini API bağlantısı test ediliyor...
✅ Gemini API çalışıyor!
🤖 AI Analiz Sonucu: {title: ..., price: ..., category: ...}
```

### Hata Logları:
```
❌ AI API Hatası: 400
❌ AI API Detaylı Hata: {message: "API key geçersiz"}
❌ AI Analiz Hatası: FormatException: ...
```

## 🐛 Yaygın Hatalar ve Çözümleri

### 1. "API key geçersiz" Hatası
**Çözüm:** Google AI Studio'dan yeni bir API key alın ve koda ekleyin

### 2. "API limiti aşıldı" Hatası
**Çözüm:** Google Cloud Console'dan kullanım limitlerini kontrol edin

### 3. "Model bulunamadı" Hatası
**Çözüm:** Model adını kontrol edin (`gemini-1.5-flash`)

### 4. "Network hatası" 
**Çözüm:** İnternet bağlantınızı kontrol edin

## 📱 Test Senaryoları

### Senaryo 1: Basit Test
1. URL girin: `https://www.trendyol.com/urun/...`
2. Bekleyin ve sonuçları kontrol edin

### Senaryo 2: Detaylı Test
1. URL girin
2. Başlık alanına ürün adı yazın
3. Açıklama alanına ürün detayları yazın
4. AI daha doğru sonuç verecektir

### Senaryo 3: Hata Testi
1. Geçersiz bir URL girin: `test123`
2. AI çalışmayacak (beklenen davranış)

## 💡 İpuçları

1. **Console loglarını filtrelemek için:**
   ```bash
   flutter run | grep -i "gemini\|AI"
   ```

2. **Logları dosyaya kaydetmek için:**
   ```bash
   flutter run > logs.txt 2>&1
   ```

3. **Hot reload yapmak için:**
   - Terminal'de `r` tuşuna basın
   - Veya VS Code'da `Ctrl+S` (Mac: `Cmd+S`)

## 🎯 Hızlı Test Komutu

Terminal'de şu komutu çalıştırarak hızlıca test edebilirsiniz:

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR" && flutter run
```

Sonra uygulamada bir URL girin ve console'u izleyin!



