Harika, profil geçmişi mantığını da ekleyerek tüm sistemi kapsayan güncellenmiş ve eksiksiz `.md` yol haritasını hazırladım. Yapay zekaya doğrudan bu son halini verebilirsin:

```markdown
# Fırsatkolik - Fırsat Temizlik, Favori ve Profil Geçmişi Sistemi Yol Haritası

Bu yol haritası; Firebase maliyetlerini minimumda tutmak, veritabanını hafifletmek, kullanıcıların geçmiş başarılarını (sosyal kanıt) profillerinde sergilemek ve kullanıcı deneyimini (UX) korumak amacıyla tasarlanmış temizlik, favori ve profil yönetim sistemini kapsamaktadır.

---

## 🚀 Genel Akış Özeti
1. Ana fırsatlar 48 saat sonra Firebase'den tamamen silinir (TTL / Cloud Functions).
2. Kullanıcı bir fırsatı favorilediğinde veya yeni bir fırsat paylaştığında, ana dökümana bağımlı olmayan minimalist "Meta Veri" kartları oluşturulur.
3. Ana fırsat silinse bile kullanıcının favorilerindeki ve profilindeki (son 5 paylaşılan) link ve temel bilgiler korunur, arayüzde "Süresi Doldu" olarak gösterilir. Bu sayede hem "Usta Avcı" profillerinin güvenilirliği (sosyal kanıt) korunur hem de Firebase şişmez.

---

## 🛠️ ADIM 1: Firebase Firestore Veri Yapısının Kurulması

Favori ve profil geçmişi dökümanlarının, ana fırsat dökümanı silindiğinde patlamaması için bağımsız (kendi kendine yeten) bir yapıda olması gerekir.

### 1. `firsat_havuzu` Koleksiyonu (Ana İlanlar)
```json
{
  "firsatId": "string",
  "baslik": "string",
  "fiyat": "string",
  "link": "string",
  "magazaAdi": "string", 
  "gorselUrl": "string", 
  "olusturulmaTarihi": "timestamp",
  "paylasanKullaniciId": "string"
}

```

### 2. `kullanici_favorileri` Alt Koleksiyonu (Kullanıcı Bazlı Meta Veri)

> ⚠️ **Not:** Bu döküman ana fırsat silinse bile veritabanından **silinmeyecektir**.

```json
{
  "favoriId": "string",
  "firsatId": "string", 
  "baslik": "string",
  "fiyat": "string",
  "link": "string", 
  "magazaAdi": "string", 
  "eklenmeTarihi": "timestamp"
}

```

### 3. `kullanici_profilleri` Koleksiyonu (Profil Geçmişi Meta Verisi)

Kullanıcının paylaştığı son 5 fırsatın, ana ilan silindikten sonra da profilinde "Başarı Madalyası" olarak kalması için profil dökümanı içinde minimalist bir dizi (array) olarak tutulacaktır.

```json
{
  "kullaniciId": "string",
  "kullaniciAdi": "string",
  "sonPaylasilanFirsatlar": [
    {
      "firsatId": "string",
      "baslik": "string",
      "fiyat": "string",
      "link": "string",
      "magazaAdi": "string",
      "paylasilmaTarihi": "timestamp"
    }
  ]
}

```

*Not: Kullanıcı yeni bir fırsat paylaştığında bu diziye ekleme yapılacak ve dizinin uzunluğu kod tarafında maksimum 5-10 ilanla sınırlandırılacaktır.*

---

## 🧹 ADIM 2: Firebase Cloud Functions (48 Saatlik TTL Temizliği)

Ana fırsat havuzunu temiz tutmak ve depolama maliyetlerini kısmak için otomatik temizlik fonksiyonu yazılacak.

* **Görev:** Her gün belirlenen bir saatte (Örn: gece 03:00) çalışacak bir `Scheduled Cloud Function` (veya Firestore TTL özelliği) kurulmalı.
* **Kural:** `olusturulmaTarihi` üzerinden 48 saat geçmiş olan tüm `firsat_havuzu` dökümanları ve bu dökümanlara bağlı `gorselUrl` (eğer Firebase Storage'da ise) tamamen silinecek.

---

## 📱 ADIM 3: Mobil Uygulama Arayüz Yönetimi (UI/UX)

Kullanıcılar "Favorilerim" veya bir başkasının "Profili" üzerinden silinmiş fırsatlara eriştiğinde akıllı bir arayüz görmelidir.

### 1. Görsel Yönetimi (Placeholder)

* Favori kartlarında ve profil geçmişi kartlarında ürün görseli (`gorselUrl`) **tutulmayacak**.
* Kartın sol tarafındaki görsel alanına, dökümandaki `magazaAdi` parametresine bakılarak uygulamanın lokalinde (assets) kayıtlı olan **Mağaza Logosu** (Trendyol, Amazon, Hepsiburada logosu vb.) basılacak.

### 2. "Süresi Doldu" Kontrolü ve Tasarımı (Favori ve Profil Sayfaları İçin)

Uygulama, favori veya profil geçmişi kartlarını ekrana basarken şu mantığı işletecek:

* Eğer kartın `eklenmeTarihi` / `paylasilmaTarihi` üzerinden 48 saat geçmişse (veya alternatif olarak ana `firsat_havuzu` koleksiyonunda bu `firsatId` artık bulunamıyorsa):
* Kartın opaklığı **%50'ye** düşürülecek (soluk görünecek).
* Kartın üzerine göze çarpan bir **"Fırsat Süresi Doldu"** veya **"Bitti"** etiketi eklenecek.
* Yönlendirme butonunun metni **"Şansını Dene / Mağazaya Git"** olarak güncellenecek.
* Kullanıcı butona tıkladığında `link` parametresi üzerinden mağazaya yine de yönlendirilecek (Affiliate/Gelir ortaklığı akışının kesilmemesi için).



### 3. Favori Temizliği (Opsiyonel & Faydalı)

* Favorilerim sayfasının üst kısmına **"Süresi Dolanları Temizle"** butonu eklenecek. Tıklandığında yerelde veya Firebase'de süresi dolmuş favori dökümanları topluca silinebilecek. (Profil sayfasındaki geçmiş ise geçmiş başarıları göstermek adına sabit kalacaktır).

```

```