# 🚀 GitHub Pages Kurulum Rehberi

## ✅ Hazırlanan Dosyalar

- ✅ `docs/index.html` - Privacy Policy sayfası
- ✅ `docs/README.md` - Açıklama dosyası

## 📋 Adım Adım Kurulum

### 1. Dosyaları Git'e Ekleyin

```bash
git add docs/
git commit -m "Add privacy policy for GitHub Pages"
git push origin main
```

### 2. GitHub'da Pages Ayarlarını Yapın

1. GitHub repository'nize gidin: `https://github.com/[kullanici-adi]/[repo-adi]`
2. **Settings** sekmesine tıklayın
3. Sol menüden **Pages** seçeneğine tıklayın
4. **Source** bölümünde:
   - **Branch:** `main` seçin
   - **Folder:** `/docs` seçin
5. **Save** butonuna tıklayın

### 3. URL'yi Alın

GitHub Pages aktif edildikten sonra (birkaç dakika sürebilir), URL şu şekilde olacak:

```
https://[kullanici-adi].github.io/[repo-adi]/
```

**Örnek:**
- Repo adı: `sicak-firsatlar`
- Kullanıcı adı: `gokayalemdar`
- URL: `https://gokayalemdar.github.io/sicak-firsatlar/`

### 4. Google Play Console'a Ekleyin

1. Google Play Console'a gidin
2. Uygulamanızı seçin
3. **Store listing** sekmesine gidin
4. **Privacy Policy** bölümüne URL'yi ekleyin:
   ```
   https://[kullanici-adi].github.io/[repo-adi]/
   ```
5. **Save** butonuna tıklayın

## ⚠️ Önemli Notlar

- GitHub Pages'in aktif olması 1-5 dakika sürebilir
- URL'yi tarayıcıda açarak test edin
- Eğer 404 hatası alırsanız, birkaç dakika bekleyip tekrar deneyin
- URL'yi Google Play Console'a ekledikten sonra, Google'ın doğrulaması birkaç saat sürebilir

## 🔍 Test

URL'yi tarayıcıda açarak test edin:
```bash
# Örnek URL'yi tarayıcıda açın
open https://[kullanici-adi].github.io/[repo-adi]/
```

## 📝 Güncelleme

Privacy Policy'yi güncellemek için:

1. `docs/index.html` dosyasını düzenleyin
2. Git'e commit edin:
   ```bash
   git add docs/index.html
   git commit -m "Update privacy policy"
   git push origin main
   ```
3. GitHub Pages otomatik olarak güncellenecektir (birkaç dakika sürebilir)






