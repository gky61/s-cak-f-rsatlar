# Kategori Nasıl Belirleniyor? (Net Akış)

Kategori **sadece Firebase Functions** tarafında, Telegram kanal mesajı işlenirken belirlenir. Flutter uygulaması Firestore’daki `category` alanını okur, **değiştirmez**.

---

## 1. Nerede belirleniyor?

| Dosya | Fonksiyon | Satır (yaklaşık) |
|-------|-----------|-------------------|
| `functions/telegram_client.js` | `parseTelegramMessage()` | 951–984 |
| `functions/telegram_client.js` | `fetchChannelMessages()` | 1140–1166 |
| Firestore’a yazılan alan | `deals` koleksiyonu | `category` (string) |

Yani: **Telegram mesajı → parseTelegramMessage + fetchChannelMessages → `parsedDeal.category` → Firestore `deals.category`.**

---

## 2. Adım adım sıra (önem sırasına göre)

### Adım 1: İlk atama – anahtar kelime (mesaj metninde)

**Yer:** `functions/telegram_client.js` → `parseTelegramMessage()` içinde.

**Ne kullanılıyor:** Mesajın **tamamı** (`messageText`), küçük harfe çevrildikten sonra.

**Nasıl:**  
`categoryKeywords` içindeki her kategori için anahtar kelimeler taranır. Mesajda geçen **en uzun** eşleşen kelime/cümle hangi kategoriye aitse, kategori o olur.

- Örnek: Mesajda hem "saat" (moda) hem "akıllı saat" (elektronik) varsa → "akıllı saat" daha uzun olduğu için **elektronik** seçilir.
- Hiçbir kelime eşleşmezse `deal.category` bu aşamada **boş string** kalır.

**Kod:**  
Satır ~951–984: `categoryKeywords` tanımı, `lowerText = messageText.toLowerCase()`, döngüyle eşleşmeler toplanıyor, `allMatches.sort((a,b) => b.len - a.len)`, `deal.category = allMatches[0].categoryId`.

---

### Adım 2: AI (Gemini) – sadece key varsa

**Yer:** `functions/telegram_client.js` → `fetchChannelMessages()` içinde.

**Ne kullanılıyor:**  
- `parsedDeal.title` (başlık)  
- `parsedDeal.description` (mesaj metni, ilk ~500 karakter)

**Ne zaman çalışır:**  
Sadece `options.geminiApiKey` doluysa. Bu key şuradan gelir:

- `functions/index.js` → `runTelegramFetch()` → `config.gemini?.apikey`
- Config: `firebase functions:config:set gemini.apikey "GEMINI_API_KEY"` ile set edilir.

**Mantık:**  
- AI kategori döndürürse: `parsedDeal.category = aiCategory` (önceki anahtar kelime sonucu ezilir).  
- AI `null` dönerse: `parsedDeal.category = normalizeBotCategoryToApp(parsedDeal.category)` (Adım 1’deki sonuç normalize edilir; boşsa `'diger'` olur).

**Kod:**  
Satır ~1141–1150: `if (options.geminiApiKey)` → `detectCategoryWithAI(title, description, apiKey)` → `parsedDeal.category = aiCategory || normalizeBotCategoryToApp(...)`.

---

### Adım 3: Başlığa göre düzeltme (elektronik / moda / market / ev)

**Yer:** Yine `fetchChannelMessages()`, Adım 2’den hemen sonra.

**Ne kullanılıyor:** Sadece **başlık** (`parsedDeal.title`).

**Nasıl:**  
- `titleSuggestsElectronics(title)` true ve kategori `'diger'` veya `'kitap_hobi'` ise → **elektronik**.  
- Benzer şekilde: moda, supermarket, ev_yasam için `titleSuggestsModa`, `titleSuggestsSupermarket`, `titleSuggestsEvYasam` true ise ve kategori `'diger'` ise ilgili kategoriye çekilir.

**Başlık nereden geliyor:**  
`parseTelegramMessage()` içinde:

- `messageText` satırlara bölünür: `lines = messageText.split('\n').filter(...)`  
- **İlk satır** başlık adayı: URL’ler çıkarılır, 100 karakterden uzunsa kısaltılır.  
- İlk satır 3 karakterden kısaysa **ikinci satır** başlık yapılır.

Yani başlık = mesajdaki ilk (veya gerekirse ikinci) anlamlı satır. Ürün adı 3. satırda vs. ise başlık yanlış olabilir; bu da “başlıktan düzeltme”nin tetiklenmemesine yol açar.

**Kod:**  
Satır ~1152–1165: `if (titleSuggestsElectronics(...) && (category === 'diger' || category === 'kitap_hobi'))` vb.

---

### Adım 4: Son fallback

**Yer:** Aynı blok.

**Kod:**  
`if (!parsedDeal.category) parsedDeal.category = 'diger';`

Yani hiçbir yerde kategori set edilmemişse **diger** yazılır.

---

## 3. Özet tablo

| Sıra | Nerede | Girdi | Çıktı / Not |
|------|--------|--------|-------------|
| 1 | `parseTelegramMessage()` | Tüm mesaj metni (`messageText`) | Anahtar kelime eşleşmesi (en uzun kazanır); yoksa `category = ''`. |
| 2 | `fetchChannelMessages()` | Başlık + açıklama (ilk 500 char) | Gemini key varsa AI kategori; yoksa Adım 1 sonucu normalize (boşsa `diger`). |
| 3 | `fetchChannelMessages()` | Sadece başlık | titleSuggests* ile `diger` / `kitap_hobi` → elektronik, moda, supermarket, ev_yasam. |
| 4 | `fetchChannelMessages()` | - | Hâlâ boşsa `parsedDeal.category = 'diger'`. |
| - | Firestore’a yazma | `parsedDeal.category` | `deals` dokümanında `category` alanı. |

---

## 4. Olası “bir şey değişmiyor” nedenleri

1. **Gemini API key set değil**  
   - `config.gemini?.apikey` boş → AI hiç çağrılmıyor.  
   - Kontrol: `firebase functions:config:get` → `gemini.apikey` var mı?  
   - Set: `firebase functions:config:set gemini.apikey "AIza..."`  
   - Sonra **functions’ı yeniden deploy** etmek gerekir (config deploy ile otomatik güncellenmez, env’e alınır).

2. **Başlık yanlış satırdan alınıyor**  
   - Ürün adı 3. satırda veya sadece görseldeyse `parsedDeal.title` ürünü yansıtmaz.  
   - “Başlıktan elektronik düzeltmesi” sadece **başlık** üzerinden çalıştığı için tetiklenmez.  
   - Çözüm: Anahtar kelimelerin **mesajın tamamında** aranması zaten var (Adım 1). Mesajda “kulaklık”, “hyperx” vb. geçiyorsa orada eşleşmesi gerekir.

3. **Mesaj formatı**  
   - Mesaj çok kısa veya sadece link/emoji ise ne anahtar kelime ne başlık yeterli bilgi taşıyabilir.  
   - Bazı kanallar ürün adını sadece görselde veriyorsa, metinde kelime olmadığı için kategori yine “diger” kalabilir.

4. **Deploy / cache**  
   - Kod değişikliği yaptıysanız mutlaka `firebase deploy --only functions` ile deploy edin.  
   - “No changes detected” çıkıyorsa önceki deploy zaten güncel kodu yüklemiş demektir.

---

## 5. Geçerli kategori ID’leri (uygulama ile aynı)

`elektronik`, `moda`, `ev_yasam`, `anne_bebek`, `kozmetik`, `spor_outdoor`, `supermarket`, `yapi_oto`, `kitap_hobi`, `diger`.

Firestore’a yazılan ve uygulamanın filtrelediği değerler bunlardır.

---

## 6. Hızlı kontrol listesi

- [ ] `firebase functions:config:get` → `gemini.apikey` dolu mu?  
- [ ] Son deploy: `firebase deploy --only functions` yapıldı mı?  
- [ ] Telegram mesajında ürün adı veya “kulaklık”, “elektronik” vb. kelime **metin olarak** var mı?  
- [ ] Cloud Functions loglarında “🤖 AI kategori:” veya “📌 Başlıktan elektronik düzeltmesi:” satırları görünüyor mu? (Görünüyorsa hangi adımın çalıştığı anlaşılır.)

Bu doküman, kategoriyi **nerede, hangi veriyle, hangi sırayla** belirlediğimizi net ve doğru şekilde açıklar.
