# Fırsatkolik - Kupon Listeleme ve Sayfa İçi Paylaşım Sistemi Yol Haritası

Bu yol haritası; uygulamaya çok fazla göz önünde olmayan, minimalist bir *Kuponlar* alanı eklemek, kupon listeleme sayfasını oluşturmak ve kupon paylaşma eylemini tamamen bu yeni sayfanın içerisine konumlandırmak için gerekli teknik ve mantıksal adımları kapsar.

Ana menüdeki ana ***Fırsat Paylaş*** butonu bu süreçten tamamen bağımsız kalacak ve sadece ürün fırsatı paylaşmaya devam edecektir.

---

## 🚀 Genel Akış Özeti

## Ana sayfadaki üst barda (App Bar) arama ikonunun yanına minimalist bir kupon ikonu eklenir. ## Bu ikona tıklandığında `KuponlarPage` (Kuponlar Sayfası) açılır. ## Kuponlar sayfasında, ürün görseli yerine **mağaza logolarının** kullanıldığı ve sağ tarafında ***Kopyala*** butonu olan kupon kartları listelenir. ## Kupon paylaşma eylemi, sadece `KuponlarPage` içerisindeki bir buton vasıtasıyla başlatılır; ana menüdeki formdan tamamen izoledir.

---

## 🛠️ ADIM 1: Firebase Firestore Veri Yapısı

Kuponların ürün fotoğrafları olmayacağı için şema oldukça hafiftir ve bağımsız bir `kuponlar` koleksiyonunda tutulacaktır.

### `kuponlar` Koleksiyonu

```json
{
    *kuponId*: *string*,
    *magazaAdi*: *string*, // Trendyol, Getir, Yemeksepeti vb.
    *baslik*: *string*, // Örn: *Tüm Sepette **100** TL İndirim*
    *aciklama*: *string*, // Örn: ***300** TL ve üzeri alışverişlerde geçerlidir.* (Opsiyonel)
    *kuponKodu*: *string*, // Örn: *TREND100*
    *olusturulmaTarihi*: *timestamp*,
    *bitisTarihi*: *timestamp*,
    *paylasanKullaniciId*: *string*
}

```

---

## 📱 ADIM 2: Ana Sayfa Üst Bar Giriş Noktası (UI)

- **Konum:** Ana sayfa üst barında (App Bar), sağ tarafındaki **Arama (Büyüteç) ikonunun hemen soluna** minimalist bir bilet/kupon ikonu (`🎟️` veya uygun bir **SVG** ikon) yerleştirilecek.
- **Aksiyon:** Kullanıcı bu ikona tıkladığında `KuponlarPage` isimli yeni bir sayfaya yönlendirilecek.

---

## 🎟️ ADIM 3: Kuponlar Sayfası Tasarımı (UI/UX)

`KuponlarPage` açıldığında Firestore'daki aktif kuponları listeleyen temiz bir liste görünümü (ListView) sunacaktır.

### 1. Kupon Kartı Bileşeni Tasarım Kuralları

Kupon kartları yatay (horizontal) bir yapıda olacak ve tam olarak şu 3 ana bölümden oluşacaktır:

- **Sol Alan (Görsel Alanı):** Ürün fotoğrafı kullanılmayacak. Dökümandaki `magazaAdi` değerine bakılarak uygulamanın yerel hafızasından (assets) ilgili **Mağaza Logosu** (Örn: Trendyol logolu kare bir görsel) basılacak.
- **Orta Alan (İçerik Alanı):** Dikey bir kolon (Column) içinde; üstte kalın, net bir **Ana Başlık** (`baslik`), altında ise daha küçük, grileşmiş ve silik bir fontta **Açıklama Metni** (`aciklama`) yer alacak.
- **Sağ Alan (Aksiyon Alanı):** Kartın en sağında şık bir kutucuk içinde **Kupon Kodu** (`kuponKodu`) basılacak. Hemen yanında veya altında bir ***Kopyala*** butonu yer alacak. Butona basıldığında kod telefonun panosuna (Clipboard) kopyalanacak ve buton anlık olarak yeşil renkli bir ***Kopyalandı! ✅*** geri bildirimi verecek.

### 2. Sayfa İçi Paylaşım Girişi

- `KuponlarPage` sayfasının sağ alt köşesine bir **Floating Action Button (**FAB**)** veya sayfanın kendi App Bar'ının sağ üst köşesine bir `+` (Ekle) ikonu yerleştirilecektir.
- **Aksiyon:** Bu butona tıklandığında doğrudan *Kupon Paylaşım Formu* açılacaktır.

---

## ✍️ ADIM 4: Kupon Paylaşım Formu

Kuponlar sayfasındaki ekleme butonuna basıldığında açılacak olan, çok fazla detay gerektirmeyen minimalist bir form sayfasıdır.

### Form Alanları:

1. **Mağaza Seçimi:** Hazır popüler mağazaların logolarıyla listelendiği basit bir Seçici (Dropdown/Picker).
2. **Kupon Başlığı:** Kısa ve net vaadi içeren metin alanı (TextField - Örn: ***150** TL İndirim*).
3. **Kupon Açıklaması:** Kuponun şartlarını içeren metin alanı (TextField - Opsiyonel - Örn: *Alt limit **500** TL*).
4. **Kupon Kodu:** Kullanıcının kopyalayacağı asıl kod (TextField - Örn: *YEMEK150*).
5. **Son Kullanma Tarihi:** Bu bilginin alınmasına gerek yok, bu bilgi db'de boş bırakılabilir.

- **Yayınlama Aksiyonu:** *Kuponu Paylaş* butonuna basıldığında veri doğrudan Firestore'daki `kuponlar` koleksiyonuna yazılır. Form kapatılarak kullanıcı `KuponlarPage` listesine geri döndürülür ve liste otomatik olarak yenilenir.

Bu kurgu, uygulamanın mimarisini tamamen modüler tutuyor. Yarın bir gün kupon özelliğini büyütmek veya tamamen kaldırmak istersen, ana sayfadaki *Fırsat Paylaş* kodlarına dokunmak zorunda kalmayacaksın. Tam bir tak-çıkar (plug-and-play) mimarisi oldu.