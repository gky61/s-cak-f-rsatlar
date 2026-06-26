# Kategori ve E‑ticaret İsmi (Mağaza) Nereden Geliyor, Neyi Yanlış Yapıyoruz?

## 1. Uygulamada gördüğün tek yol: Firestore → Ekran

Uygulama **kategori** ve **mağaza**yı sadece Firestore’daki `deals` dokümanlarından okuyor. Başka kaynak yok.

```
Firestore: deals koleksiyonu
  ├── category  (string)  →  Ekranda "Kategori" / filtre
  └── store    (string)  →  Ekranda "Satıcı" / "Mağaza"
         ↓
Deal.fromFirestore(data)  →  deal.category, deal.store
         ↓
deal_card / deal_detail_screen  →  Category.getById(deal.category).name, deal.store
```

Yani **doğru görünen ürünler** = Firestore’da o deal için `category` ve `store` doğru dolu. **Yanlış/eksik görünenler** = Firestore’da o deal için bu alanlar yanlış veya boş/“Diğer”/“Bilinmeyen”.

---

## 2. Firestore’a kim ne yazıyor? (İki kaynak)

| Kaynak | Ne zaman | category | store |
|--------|----------|----------|--------|
| **A) Telegram botu** | Kanal mesajı işlenince (`processTelegramChannel` → `fetchChannelMessages`) | Bot mantığı (aşağıda) | Bot mantığı (aşağıda) |
| **B) Kullanıcı (uygulama)** | Fırsat paylaş ekranından gönderince | Kullanıcı formda seçer | Kullanıcı yazar/seçer |
| **C) Admin (uygulama)** | Deal detayda “Düzenle” ile kaydedince | Admin seçer | Admin yazar |

- **Doğru görünen ürünler** büyük ihtimalle:
  - **B:** Kullanıcı paylaştığı fırsatlar (kategori + mağaza formdan geliyor), veya  
  - **A:** Bot’un doğru tespit ettiği mesajlar (mesaj/link formatı uygun), veya  
  - **C:** Admin elle düzeltmiş.
- **Yanlış/eksik görünenler** çoğunlukla:
  - **A:** Bot’un yazdığı deal’lar ve bot mantığı o mesajda mağaza/kategoriyi bulamadı veya yanlış buldu.

Yani “hangi yolu izliyor da görünüyor?” sorusunun cevabı: **Hep aynı yol (Firestore → uygulama)**; fark, veriyi **kimin** ve **hangi kurallarla** Firestore’a yazdığı.

---

## 3. Bot doğru yazdığında (doğru görünen bot fırsatları)

Bot sadece **Telegram mesaj metni + mesajdaki link**e bakıyor. Görsele bakmıyor.

**Mağaza doğru olur:**

- Mesajda “Hepsiburada”, “Trendyol”, “N11” vb. geçiyorsa **veya**
- Link doğrudan mağaza domain’i (hepsiburada.com, trendyol.com …) ise **veya**
- Link kısa link (bit.ly vb.) ise ve **kısa link çözümleme** son URL’yi bulup oradan mağaza tespit ediyorsa (şu anki kodda var).

**Kategori doğru olur:**

- Mesajın **tamamında** kategori anahtar kelimesi geçiyorsa (en uzun eşleşen kazanıyor), **veya**
- Gemini API key set ise ve AI doğru kategori döndüyse, **veya**
- Başlık veya mesaj metninde “elektronik / moda / market / ev” ifadeleri varsa ve mevcut kategori `diger` (veya elektronik için `kitap_hobi`) ise “başlık/metin düzeltmesi” ile elektronik/moda/supermarket/ev_yasam yapılıyorsa.

Bu koşullar sağlanan mesajlar → Firestore’a doğru `category` ve `store` yazılıyor → uygulamada doğru görünüyor.

---

## 4. Neyi yanlış yapıyoruz? (Bot yanlış/eksik yazdığında)

Bot **sadece metin + link** kullanıyor. Aşağıdakiler yanlış veya eksik sonuca yol açıyor:

### 4.1 Mağaza (store)

- **Mesajda mağaza adı yok** (sadece link var).
- **Link kısa link** (bit.ly, t.co vb.):
  - Çözümleme kodu var ama bazen timeout/redirect hatası olabiliyor.
  - Veya deploy/cache nedeniyle eski kod çalışıyor olabilir.
- **Link farklı domain** (affiliate, tracking): Son URL mağaza değilse mağaza yanlış/garip çıkıyor.

Sonuç: `store` boş veya “Bilinmeyen”/“Diğer” kalıyor → uygulama “Satıcı: Diğer” vb. gösteriyor.

### 4.2 Kategori (category)

- **Mesajda kategori kelimesi yok:**  
  Ürün adı sadece görselde veya çok kısa/emoji bir metin ise anahtar kelime eşleşmiyor → kategori boş kalıyor → fallback `diger`.
- **Ürün adı ilk satırda değil:**  
  Başlık = ilk (veya ikinci) satır alınıyor. Ürün adı 3. satırda vs. ise “başlıktan düzeltme” artık başlık + metin (ilk ~600 karakter) ile çalışıyor; yine de metinde “kulaklık”, “elektronik”, “hyperx” vb. yoksa düzeltme tetiklenmiyor.
- **Gemini API key set değil:**  
  `functions.config().gemini.apikey` boşsa AI hiç çağrılmıyor. Sadece anahtar kelime + başlık/metin düzeltmesi kalıyor; ikisi de eşleşmezse `diger`.
- **Türkçe karakter / yazım farkı:**  
  Anahtar kelimeler birebir (örn. “kulaklık”). Mesajda “Kulaklik”, “KULAKLIK” gibi yazılıyorsa `toLowerCase()` ile eşleşir; ama “kulaklığı” gibi farklı formlar listeye ekli değilse bazen kaçabilir.

Sonuç: `category` = `diger` veya yanlış kategori → uygulamada “Diğer” veya yanlış kategori görünüyor.

---

## 5. Özet tablo: Hangi yol, ne zaman doğru/yanlış?

| Görünen | Olası kaynak | Açıklama |
|--------|----------------|----------|
| Kategori + mağaza doğru | Kullanıcı paylaşımı | Formdan seçildiği için doğru yazılıyor. |
| Kategori + mağaza doğru | Bot | Mesajda mağaza adı veya çözülen link + kategori kelimesi/AI/başlık-metin düzeltmesi var. |
| Kategori + mağaza yanlış/eksik | Bot | Mesajda mağaza yok + link kısa/çözülemiyor veya mesajda kategori kelimesi yok + AI yok/yanlış + düzeltme tetiklenmiyor. |

Yani **gösterilen her şey** aynı yolu izliyor (Firestore → Deal → UI). Fark, **veriyi kimin yazdığı** ve **bot’un o mesajda ne bulabildiği**. Doğru görünenler bu kurallarla doğru yazılmış; yanlış görünenlerde de “neyi yanlış yapıyoruz?” sorusunun cevabı: Bot’un sadece metin + linke bakması, kısa link / mesaj formatı / Gemini key / anahtar kelime kapsamı gibi noktaların bazı mesajlarda yetersiz kalması.

---

## 6. Ne yapılabilir? (Pratik adımlar)

1. **Gemini API key:**  
   `firebase functions:config:set gemini.apikey "..."` ve sonra `firebase deploy --only functions`. Böylece AI kategori katmanı devreye girer.
2. **Kısa link + mağaza:**  
   Kısa link çözümleme zaten var; deploy’un güncel olduğundan emin ol. Hâlâ “Bilinmeyen” çoksa timeout/redirect limitini veya alternatif domain listesini gözden geçir.
3. **Anahtar kelime + düzeltme:**  
   Elektronik için “kulaklık”, “hyperx”, “oyuncu kulaklığı” vb. eklendi; başlık + mesaj gövdesi (titleAndBody) ile düzeltme kullanılıyor. Yine kaçan ürünler için kelime listesini ve `titleSuggests*` mantığını genişletebilirsin.
4. **Admin düzeltmesi:**  
   Yanlış kalan bot fırsatlarını admin panelden tek tek düzeltebilirsin; kaydedince Firestore güncellenir ve uygulama aynı yol (Firestore → ekran) ile doğru gösterir.

Bu doküman, “bazı ürünlerin kategori ve e‑ticaret ismi belirlenip uygulamada gösterilmesi”nin **hangi yolu izlediğini** (Firestore’dan okuma) ve **neyi yanlış yaptığımızı** (bot’un sadece metin + linke bağlı kalması ve bazı mesajlarda bunun yetersiz kalması) net ve doğru şekilde açıklar.
