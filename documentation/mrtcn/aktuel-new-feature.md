# Fırsatkolik - Aktüel Kataloglar Modülü Yol Haritası

Bu yol haritası; süpermarket ve kozmetik mağazalarının dönemsel indirim kataloglarını (broşürlerini) markalarına göre gruplayıp, tek bir doğrusal akışla (Mağaza Seçimi -> Katalog Listesi -> Katalog Detay) temiz bir arayüzde listelemek için gerekli mantıksal ve teknik adımları kapsar. 

Akışta hiçbir mağaza için istisna veya kısayol uygulanmayacak, tek bir katalog olsa dahi her zaman aynı adımlar takip edilecektir.

---

## 🚀 Genel Akış Özeti (Doğrusal Yapı)
1. Ana sayfa üst barında (App Bar), Kuponlar ikonunun hemen yanına şık bir "Katalog" (`📰` veya `📖`) ikonu eklenir.
2. **Seviye 1 (Mağazalar):** İkona tıklandığında desteklenen tüm büyük markaların logolarından oluşan temiz bir grid ekranı açılır.
3. **Seviye 2 (Katalog Listesi):** Bir markaya tıklandığında, o markaya ait kataloglar (tek bir broşür olsa dahi) küçük kapak görselleri ve tarih aralıklarıyla listelenir.
4. **Seviye 3 (Katalog Detay):** Listeden bir kataloğa tıklandığında görseller tam ekran açılır; birden fazla sayfa varsa sağa/sola kaydırılarak incelenir.

---

## 🛠️ ADIM 1: Firebase Firestore Veri Yapısı

Katalog verileri, her gecenin taranan güncel broşürlerini tutmak üzere bağımsız bir `kataloglar` koleksiyonunda saklanacaktır.

```json
{
  "katalogId": "string",
  "magazaKodu": "string", // bim, a101, sok, migros, gratis, watsons vb.
  "katalogBasligi": "string", // Örn: "Haftanın Yıldızları", "Hafta Sonu Fırsatları"
  "baslangicTarihi": "timestamp",
  "bitisTarihi": "timestamp",
  "sayfaResimleri": [
    "[https://cdn.firsatkolik.com/kataloglar/bim_sayfa1.jpg](https://cdn.firsatkolik.com/kataloglar/bim_sayfa1.jpg)",
    "[https://cdn.firsatkolik.com/kataloglar/bim_sayfa2.jpg](https://cdn.firsatkolik.com/kataloglar/bim_sayfa2.jpg)"
  ],
  "kapakResmi": "string" // Listeleme ekranında (Seviye 2) görünecek küçük önizleme görseli URL'i
}

```

---

## 📱 ADIM 2: Seviye 1 - Mağaza Seçim Ekranı (UI)

* **Giriş Noktası:** Ana sayfa üst barında (App Bar), sağ taraftaki Kuponlar ikonunun hemen yanına yerleştirilecek katalog butonuna basıldığında `AktuelMagazalarPage` açılır.
* **Tasarım:** Yan yana 3'lü dizilimde bir GridView şeklinde desteklenen markaların renkli logoları listelenir.
* *Markalar:* BİM, ŞOK, A101, Migros, CarrefourSA, Çağrı, HappyCenter, MacroCenter, GetirBüyük, File, Hakmar, Gratis, Watsons.


* **Aksiyon:** Kullanıcı herhangi bir logoya tıkladığında, içerideki katalog sayısından bağımsız olarak **HER ZAMAN** doğrudan `KatalogListesiPage` (Seviye 2) ekranına yönlendirilir. Kesinlikle hiçbir atlama veya otomatik geçiş mantığı uygulanmaz.

---

## 📄 ADIM 3: Seviye 2 - Mağaza Katalog Listesi Ekranı (UI/UX)

Seçilen mağazaya ait tüm aktif broşürlerin topluca listelendiği, tutarlılığı sağlayan ana ara ekrandır.

* **Tasarım:** Yan yana 2'li şık kartlar (Grid) halinde tasarlanır. Mağazanın o an sadece tek bir kataloğu varsa, ekranda tek bir kart listelenir.
* **Kart İçeriği:**
* Üstte kataloğun küçük önizleme görseli (`kapakResmi`).
* Altında kataloğun başlığı (Örn: "Aldın Aldın Kampanyası").
* En altta ise daha küçük ve silik fontta geçerlilik tarihi aralığı: **"1 Temmuz - 31 Temmuz"** metni yer alır.


* **Aksiyon:** Kullanıcı bir karta tıkladığında ilgili kataloğun tam ekran incelenebileceği detay sayfasına (`KatalogDetayPage`) geçiş yapar.

---

## 🖼️ ADIM 4: Seviye 3 - Katalog Detay ve Kaydırma Ekranı (UI/UX)

Kataloğun sayfalarının tam ekran ve yüksek çözünürlüklü olarak incelendiği alandır.

* **Instagram Tarzı Kaydırma (PageView):** Sayfada yatay eksende kaydırılabilir bir yapı (`PageView.builder`) kullanılacaktır. Kullanıcı parmağıyla sağa sola çekerek broşür sayfaları arasında akıcı geçiş yapabilir. Eğer katalog tek bir sayfadan oluşuyorsa kaydırma özelliği pasif olur, sadece tek resim görünür.
* **Sayfa İndikatörü (Dots Indicator):** Eğer katalog birden fazla sayfadan oluşuyorsa, ekranın alt orta kısmında kullanıcının kaçıncı sayfada olduğunu gösteren küçük noktalar (indikatör) yer alacaktır.
* **Çift Parmakla Büyütme Desteği (Pinch-to-Zoom):** Katalog resimleri `InteractiveViewer` bileşeni ile sarmalanacaktır. Kullanıcı iki parmağıyla resmi büyüterek broşürdeki küçük ürün fiyatlarını ve detaylarını netçe okuyabilecektir.
* **Üst Bilgi Barı:** Sayfanın en üstünde mağazanın adı ve kataloğun son geçerlilik tarihi (Örn: "BİM - Son Gün: 31 Temmuz") sabit olarak görünecektir.

---

## 🛡️ ADIM 5: Otomatik Süre Takibi ve Filtreleme

* Kullanıcı arayüzde katalogları listelerken (Seviye 2), backend sorgusunda her zaman cihazın o anki zaman filtresi (`DateTime.now()`) çalışacaktır.
* `bitisTarihi` geçmiş olan dökümanlar Firestore sorgusunda elenecek ve kullanıcıya asla gösterilmeyecektir. Böylece listeler her zaman güncel kalacaktır.
