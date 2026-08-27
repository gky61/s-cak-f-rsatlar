# Fırsatkolik - Kupon Listeleme, Sayfa İçi Paylaşım ve Sade Oylama Sistemi

> [!NOTE]
> Bu doküman iki sekmeli kupon mimarisinin ilk ürün yol haritasıdır. Sistemin canlıdaki eksiksiz mimari, 3 kademeli Wilson Score sıralama algoritması, idempotent oylama motoru, multi-source kazıyıcı ve şalter kontratı için lütfen **[Kuponlar ve İndirim Kodları Master Mimari Rehberi](file:///d:/firsatkolik/documentation/kuponlar/kuponlar_modulu_rehberi.md)** dokümanını inceleyiniz.

Bu yol haritası; uygulamaya çok fazla göz önünde olmayan, minimalist bir "Kuponlar" alanı eklemek, kupon listeleme sayfasını oluşturmak ve kuponların doğruluğunu Fırsatkolik'in özü olan kalıcı "Sıcak/Soğuk" (Çalıştı/Çalışmadı) butonlarıyla topluluğa oylatmak için gerekli teknik ve mantıksal adımları kapsar.

---

## 🚀 Genel Akış Özeti
1. Ana sayfadaki üst barda (App Bar) arama ikonunun yanına minimalist bir kupon ikonu eklenir.
2. Bu ikona tıklandığında iki sekmeli (**Topluluk Kuponları** / **Kupon Radarı**) `KuponlarPage` açılır.
3. Kupon kartları üzerinde ürün görseli yerine mağaza logoları kullanılır; kartın altında kalıcı ve tıklanabilir Sıcak (🔥) / Soğuk (❄️) oylama ikonları yer alır.
4. Kupon paylaşma eylemi, sadece `KuponlarPage` içerisindeki bir buton vasıtasıyla başlatılır; ana menüdeki formdan tamamen izoledir.

---

## 🛠️ ADIM 1: Firebase Veri Yapısı

Kuponların ürün fotoğrafları olmayacağı için şema oldukça hafiftir ve bağımsız bir `kuponlar` koleksiyonunda tutulacaktır.

### `kuponlar` Koleksiyonu İsterleri
* Kupon ID, Mağaza Adı, Başlık, Kupon Kodu, Oluşturulma Tarihi, Bitiş Tarihi, Paylaşan Kullanıcı ID.
* **Kaynak Tipi:** "topluluk" (kullanıcı eklemesi) veya "web" (bot/radar eklemesi).
* **Oylama Sayaçları:** `sicakOySayisi` (sayı) ve `sogukOySayisi` (sayı).
* **Durum:** "aktif" veya "gecersiz".

---

## 📱 ADIM 2: Ana Sayfa Üst Bar Giriş Noktası (UI)

* **Konum:** Ana sayfa üst barında (App Bar), sağ taraftaki **Arama (Büyüteç) ikonunun hemen soluna** minimalist bir bilet/kupon ikonu yerleştirilecek.
* **Aksiyon:** Kullanıcı bu ikona tıkladığında `KuponlarPage` isimli yeni bir sayfaya yönlendirilecek.

---

## 🎟️ ADIM 3: Kuponlar Sayfası ve Sade Tab Yapısı (UI/UX)

`KuponlarPage` sayfasının üst kısmında iki sekmeli bir yapı (TabBar) yer alacaktır. Sayfa ilk açıldığında varsayılan olarak birinci sekme aktif gelecektir:
1. **Topluluk Kuponları:** Sadece `kaynakTipi == "topluluk"` ve durumu aktif olan kuponlar listelenir.
2. **Kupon Radarı:** `kaynakTipi == "web"` olan (sistemin internetten otomatik tarayıp bulduğu) kuponlar listelenir.

### 1. Kupon Kartı Bileşeni Tasarım Kuralları
Kupon kartları yatay (horizontal) bir yapıda olacak ve tam olarak şu 3 ana bölümden oluşacaktır:

* **Sol Alan (Görsel Alanı):** Ürün fotoğrafı kullanılmayacak. Mağaza adına bakılarak uygulamanın yerel hafizasından (assets) ilgili **Mağaza Logosu** (Örn: Trendyol logosu) basılacak.
* **Orta Alan (İçerik ve Oylama Alanı):** Dikey bir kolon (Column) yapısında çalışacaktır:
  * Üstte kalın ve net bir **Ana Başlık**, altında ise daha küçük ve silik fontta bir **Açıklama Metni** yer alacak.
  * Bu metinlerin hemen altında, kalıcı olarak yan yana duran iki adet şık, minimalist **Oylama İkonu (Butonu)** yer alacaktır: 
    * `🔥 [Sıcak Oy Sayısı]`  |  `❄️ [Soğuk Oy Sayısı]`
* **Sağ Alan (Aksiyon Alanı):** Kartın en sağında şık bir kutucuk içinde **Kupon Kodu** basılacak. Hemen yanında veya altında bir **"Kopyala"** butonu yer alacak. Butona basıldığında kod panoya kopyalanacak ve buton anlık olarak yeşil renkli bir **"Kopyalandı! ✅"** uyarısı verecektir.

### 2. Kalıcı İkonlar Üzerinden Oylama Mantığı (UX)
* Kartın üzerindeki 🔥 ve ❄️ ikonları sadece birer gösterge değil, doğrudan **tıklanabilir butonlardır**.
* Kullanıcı kuponu deneyip uygulamaya geri döndüğünde (veya istediği herhangi bir anda) bu ikonlara tıklayarak oyu verebilir.
* Kullanıcı bir ikona tıkladığında veritabanındaki ilgili sayaç anında 1 artırılacak ve kart üzerindeki sayı canlı olarak güncellenecektir (Kullanıcı her kupona sadece 1 kez oy verebilir).

### 3. Otomatik Temizlik ve Arşiv Algoritması
* Eğer bir kuponun `sogukOySayisi` (Çalışmadı oyu), `sicakOySayisi` (Çalıştı oyu) değerinden **5 adet daha fazla** olursa (Net skor < -5):
  * Kuponun durum değeri otomatik olarak `"gecersiz"` yapılacaktır.
  * Geçersiz olan kuponlar **"Topluluk Kuponları"** sekmesinde soluklaşarak (%40 opaklık) listenin en sonuna atılacak, **"Kupon Radarı"** sekmesinde ise veritabanından tamamen silinecektir.

---

## ✍️ ADIM 4: Kupon Paylaşım Girişi ve Formu

* `KuponlarPage` sayfasının sağ alt köşesine bir **Floating Action Button (FAB)** veya sayfa App Bar'ının sağ üst köşesine bir `+` (Ekle) ikonu yerleştirilecektir.
* **Aksiyon:** Bu butona tıklandığında minimalist "Kupon Paylaşım Formu" açılacaktır.

### Form Alanları:
1. **Mağaza Seçimi:** Popüler mağazaların listelendiği basit bir Seçici (Dropdown).
2. **Kupon Başlığı:** Net vaadi içeren kısa metin alanı (Örn: "100 TL İndirim").
3. **Kupon Açıklaması:** Şartları içeren metin alanı (Opsiyonel - Örn: "300 TL alt limitte geçerli").
4. **Kupon Kodu:** Kullanıcının kopyalayacağı asıl kod (Örn: "YEMEK100").
5. **Son Kullanma Tarihi:** Kuponun geçerlilik süresi (DatePicker - Opsiyonel).

* **Yayınlama:** "Kuponu Paylaş" butonuna basıldığında kaynak tipi "topluluk", sayaçlar ise "0" olarak ayarlanıp veritabanına yazılır. Form kapatılarak liste otomatik yenilenir.