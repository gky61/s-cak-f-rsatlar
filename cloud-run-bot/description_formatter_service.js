/**
 * FırsatKolik - Akıllı İçerik, Açıklama Temizleme & Marka Özgünleştirme Motoru
 * (Smart Description Formatter & Brand Enrichment Service)
 * 
 * Felsefe:
 * 1. Yalnızca GERÇEKTEN BARİZ olan çöp metinleri (CTA butonları, rakip kanal davetleri,
 *    editör imzaları, mükerrer başlık ve çıplak fiyat) keser/temizler.
 * 2. Ürün isimlerinde ve özelliklerinde geçebilecek hiçbir kelimede (örn. "kanal", "al", "grup",
 *    "tıkla", "adet") katı veya aşırı kural uygulamaz; cümlenin bölünmesine asla izin vermez.
 * 3. Orijinal açıklamada bulunan kıymetli kampanya şartlarını (kupon, sepet indirimi, adet koşulu)
 *    bozmadan, doğal haliyle korur.
 * 4. FırsatKolik'e özel editoryal başlık, dinamik güven rozeti ve 1 Ağustos Ticari Reklam
 *    Yönetmeliği (#tanıtım) etiketi ile profesyonel bir marka kimliği kazandırır.
 */

const advertisingComplianceService = require('./advertising_compliance_service');

// 🛑 1. BARİZ KESME / BUDAMA TETİKLEYİCİLERİ (Obvious Truncation Triggers)
// Yalnızca %100 bariz olan buton, kanal daveti ve editör imzalarında kesme yapar.
// Ürün detaylarını veya kampanya koşullarını (örn. "3 al 2 öde", "çift kanal ram") ASLA kesmez.
const TRUNCATION_LINE_PATTERNS = [
  // Bariz CTA Buton & Link Yönlendirme Kalıpları
  /(?:👉|🔗|👇|➡️|🛒)\s*(?:fırsata\s*git|ürüne\s*git|linke\s*git|satın\s*al|tıkla)/i,
  /\b(?:fırsata|firsata|ürüne|urune|linke)\s*(?:git|gidin)\b/i,
  /\b(?:satın|satin)\s*almak\s*için\s*(?:tıkla|tikla|[:\-])/i,
  /^\s*(?:👉|🔗|👇|➡️|🛒)?\s*(?:satın|satin)\s*al(?:mak\s*için)?\s*[:\-]?\s*$/i,
  /\b(?:fırsat|firsat|ürün|urun)\s*linki\s*:/i,
  /\blink\s*(?:aşağıda|asagida|profilde|biyografide)\b/i,

  // Bariz Kanal / Grup / Topluluk Davet Kalıpları (Tek başına "kanal" veya "grup" kelimesi aranmaz!)
  /\bdiğer\s+kanallar(?:ımız|imiz)?\b/i,
  /\bdiğer\s+kanal(?:ımız|imiz)?\b/i,
  /\b(?:kanalımıza|kanalimiza)\s+(?:katılın|katilin|katıl|katil|abone)\b/i,
  /\b(?:kanala)\s+(?:katılın|katilin|katıl|katil|abone)\b/i,
  /\b(?:telegram|whatsapp)\s+kanal(?:ımız|imiz|ı|i)?\b/i,
  /\b(?:telegram|whatsapp)\s+grub(?:umuz|u)?\b/i,
  /\b(?:t\.me\/|telegram\.me\/|wa\.me\/)\b/i,

  // Bariz Editör / Moderatör İmzaları ("yazar" çıkarıldı: Kitap yazarları korunur)
  /^\s*(?:editör|editor|paylaşan|paylasan|moderatör|moderator|admin)\s*[:\-]/i,

  // Bariz Rakip Platform Adları ve Satır Başı @ Kanal İsimleri
  /\b(?:tazefırsat|tazefirsat|fırsatkaplanı|firsatkaplani|indirimkaplanı|indirimkaplani|fırsatavcısı|firsatavcisi|sıcakfırsat|sicakfirsat|donanımhaber|donanimhaber)\b/i,
  /^\s*(?:👉|🔗|👇|➡️|🛒)?\s*@([a-zA-Z0-9_]{3,})\b/i,
];

// 🏷️ 2. FIRSATKOLİK DİNAMİK BAŞLIK ROTASYONLARI
const BRAND_HEADERS = [
  '✨ FırsatKolik İndirim Notu',
  '🎯 FırsatKolik Fırsat Radarı',
  '💡 FırsatKolik Editör Notu',
  '🔥 FırsatKolik Avantaj Notu',
  '⚡ FırsatKolik Fırsat Özeti'
];

// 🛡️ 3. FIRSATKOLİK DİNAMİK GÜVEN & MARKA DOKUNUŞU (Micro-Copy Footers)
const BRAND_FOOTERS = [
  '⚡ FırsatKolik ile yakaladınız! İndirim ve stoklar anlık değişebilir.',
  '🛡️ FırsatKolik İpucu: Avantajlı fiyattan yararlanmak için tükenmeden sepetinize ekleyin.',
  '🚀 En sıcak fırsatları kaçırmamak için FırsatKolik bildirimlerinizi açık tutun!',
  '✨ Bu fırsat FırsatKolik akıllı indirim radarı tarafından tespit edilmiştir.',
  '🔥 Tasarrufun en kolik hali — FırsatKolik ile kazançlı alışverişler.'
];

/**
 * Verilen metin veya ID'ye göre deterministik index seçer.
 */
function getDeterministicIndex(seed, length) {
  if (!seed) return 0;
  let hash = 0;
  const str = String(seed);
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash) % length;
}

/**
 * Satırın bir kesme/budama tetikleyicisi içerip içermediğini denetler.
 * Yalnızca bariz kanal daveti, CTA butonu veya rakip ismi varsa true döner.
 */
function isTruncationTriggerLine(line) {
  if (!line || typeof line !== 'string') return false;
  const trimmed = line.trim();
  if (!trimmed) return false;

  const lowerStandard = trimmed.toLowerCase();
  const lowerTurkish = trimmed.toLocaleLowerCase('tr-TR');

  for (const pattern of TRUNCATION_LINE_PATTERNS) {
    if (pattern.test(lowerStandard) || pattern.test(lowerTurkish)) {
      return true;
    }
  }

  return false;
}

/**
 * Metinden bariz Editör, CTA, Buton ve Rakip Kanal satırlarını temizler.
 */
function truncateEditorAndFooterInfo(rawText) {
  if (!rawText) return '';

  const lines = rawText.split(/\r?\n/);
  const cleanLines = [];

  for (const line of lines) {
    const trimmedLine = line.trim();
    if (!trimmedLine) {
      cleanLines.push(line);
      continue;
    }

    if (isTruncationTriggerLine(trimmedLine)) {
      // Bariz kesme noktası bulundu, bu satır ve sonrasını dahil etme
      break;
    }

    cleanLines.push(line);
  }

  return cleanLines.join('\n').trim();
}

/**
 * İki metin arasındaki kelime benzerliğini hesaplar (0.0 - 1.0)
 */
function calculateWordOverlap(str1, str2) {
  if (!str1 || !str2) return 0;
  const normalize = s => s.toLowerCase().replace(/[^\w\sğüşıöç]/gi, ' ').split(/\s+/).filter(w => w.length > 2);
  const words1 = new Set(normalize(str1));
  const words2 = new Set(normalize(str2));
  if (words1.size === 0 || words2.size === 0) return 0;

  let common = 0;
  for (const w of words1) {
    if (words2.has(w)) common++;
  }
  return common / Math.min(words1.size, words2.size);
}

/**
 * Satırın yalnızca çıplak fiyat içerip içermediğini denetler.
 * (Eğer kupon, sepet veya adet şartı varsa çıplak fiyat sayılmaz, kesinlikle korunur!)
 */
function isBarePriceLine(line) {
  if (!line) return false;
  const trimmed = line.trim();
  const lower = trimmed.toLowerCase();

  // Şart veya avantaj kelimeleri içeriyorsa çıplak fiyat değildir, değerlidir!
  const conditionWords = ['adet', 'sepette', 'kupon', 'kod', 'ile', 'düşüyor', 'dusuyor', 'özel', 'ozel', 'kargo', 'nays', 'bonus', 'maximum', 'world', 'kart'];
  if (conditionWords.some(w => lower.includes(w))) {
    return false;
  }

  // Emojileri temizle ve çıplak fiyat kalıbını test et (örn: "💳 207 TL 🔥", "207,00 ₺", "Fiyat: 199 TL")
  const textWithoutEmojis = trimmed.replace(/[\u{1F300}-\u{1F9FF}]|[\u{2700}-\u{27BF}]|[\u{2600}-\u{26FF}]/gu, '').trim();
  const barePriceRegex = /^(?:fiyat|fiyatı)?\s*[:\-]?\s*(?:TL|₺)?\s*\d+(?:[\.,]\d+)?\s*(?:TL|₺|lira)?$/i;
  return barePriceRegex.test(textWithoutEmojis);
}

/**
 * Satırın ürün başlığıyla aşırı benzer olup olmadığını kontrol eder.
 * EĞER satır indirim şartı, sepet veya kupon içeriyorsa ASLA başlık sayılmaz!
 */
function isDuplicateTitleLine(line, dealTitle) {
  if (!line || !dealTitle) return false;

  // Güvenlik Kilidi: İndirim şartı, kupon veya sepet bilgisi taşıyorsa asla silinmez!
  const conditionRegex = /\b(?:adet|sepette|kupon|kuponu|kod|kodu|ekle|ekleyin|ekleyiniz|ödeme|odeme|aşamasında|asamasinda|indirim|indirimli|düşüyor|dusuyor|hediye|taksit|kargo|bedava|ücretsiz|ucretsiz)\b/i;
  if (conditionRegex.test(line)) {
    return false;
  }

  const cleanLine = line.replace(/[\u{1F300}-\u{1F9FF}]|[\u{2700}-\u{27BF}]|[\u{2600}-\u{26FF}]|🔎|🔥|⚡/gu, '').trim();
  if (cleanLine.length < 5) return false;

  const overlap = calculateWordOverlap(cleanLine, dealTitle);
  return overlap >= 0.7; // Yüksek eşik (sadece gerçekten bariz başlık tekrarlarını siler)
}

/**
 * Satırdan reklam/tanıtım/işbirliği takılarını temizler (örneğin "🛍️ Amazon (Satıcı : Amazon) Tanıtım" -> "🛍️ Amazon (Satıcı: Amazon)")
 */
function cleanInlineAdTags(line) {
  if (!line) return '';
  // 1. Hashtag veya parantez/köşeli parantez içindeki etiketleri temizle (#tanıtım, [Reklam], (İşbirliği))
  let cleaned = line.replace(/(?:#|\[|\()(?:reklam|reklamdır|reklamdir|tanıtım|tanitim|işbirliği|isbirligi|sponsorlu|ortaklık|ortaklik|affiliate)(?:\]|\))?/gi, '');
  
  // 2. Satırın en sonundaki tekil tanıtım/reklam takısını temizle (Örn: "... Amazon) Tanıtım" -> "... Amazon)")
  // Cümle içindeki normal kullanımlara (örn. "tanıtım lansman fiyatı", "reklam ajansı") ASLA dokunmaz!
  cleaned = cleaned.replace(/\s+(?:reklam|tanıtım|tanitim|işbirliği|isbirligi|sponsorlu)\s*$/gi, '');

  return cleaned.replace(/\s+/g, ' ').trim();
}

/**
 * Ana Açıklama Formatlayıcı ve Özgünleştirme Motoru
 * 
 * @param {Object} params
 * @param {string} params.rawText - Telegram mesajının ham metni
 * @param {Array<string>} [params.links] - Mesajda tespit edilen linkler (çıkarılmak üzere)
 * @param {string} [params.title] - Fırsatın temizlenmiş başlığı
 * @param {string} [params.store] - Mağaza adı (Örn: Amazon, Trendyol)
 * @param {string} [params.category] - Kategori adı
 * @param {string|number} [params.seed] - Dinamik başlık ve footer seçimi için tohum
 * @returns {string} - %100 temizlenmiş, doğal ve FırsatKolik imzalı açıklama
 */
function formatAndEnrichDescription({
  rawText = '',
  links = [],
  title = '',
  store = '',
  category = '',
  seed = ''
} = {}) {
  let text = (rawText || '').trim();

  // 1. Bilinen linkleri metinden çıkar
  if (Array.isArray(links)) {
    for (const link of links) {
      if (link) {
        text = text.replace(link, '');
      }
    }
  }

  // 2. Bariz Editör, CTA buton, Telegram kanal adı ve rakip yönlendirmelerini buda
  text = truncateEditorAndFooterInfo(text);

  // 3. Satır satır filtreleme (Aşırı kurallardan kaçınılır, metin doğallığı korunur)
  const rawLines = text.split(/\r?\n/);
  const curatedLines = [];

  for (let i = 0; i < rawLines.length; i++) {
    let line = rawLines[i].trim();
    if (!line) continue;

    // Satır içi reklam/tanıtım kelimelerini arındır
    line = cleanInlineAdTags(line);
    if (!line) continue;

    // Sadece ilk satır ürün başlığıyla neredeyse birebir aynıysa atla
    if (i === 0 && isDuplicateTitleLine(line, title)) {
      continue;
    }

    // Yalnızca tek başına çıplak fiyat satırı ise (başka bir açıklama içermiyorsa) atla
    if (isBarePriceLine(line)) {
      continue;
    }

    // Metnin doğallığını ve orijinal yazarın ifadesini koru
    curatedLines.push(line);
  }

  // 4. Deterministik Varyasyon Seçimi
  const headerIdx = getDeterministicIndex(seed || title || 'firsatkolik', BRAND_HEADERS.length);
  const footerIdx = getDeterministicIndex(seed || title || 'firsatkolik_footer', BRAND_FOOTERS.length);

  const brandHeader = BRAND_HEADERS[headerIdx];
  const brandFooter = BRAND_FOOTERS[footerIdx];

  // 5. İçerik Birleştirme veya Fallback Üretimi
  let finalBody = '';

  if (curatedLines.length > 0) {
    // Kıymetli detayları doğal akışıyla birleştir
    const bodyContent = curatedLines.join('\n\n');
    finalBody = `${brandHeader}\n\n${bodyContent}\n\n${brandFooter}`;
  } else {
    // Açıklama yoksa veya tümü link olduğu için silindiyse özgün FırsatKolik açıklaması üret
    const storeMention = store && store !== 'Diğer' && store !== 'Telegram' ? `${store} üzerinde ` : '';
    const categoryMention = category && category !== 'diger' ? `${category} kategorisinde ` : '';

    finalBody = `${brandHeader}\n\n🎯 ${storeMention}${categoryMention}dikkat çeken bu fırsat avantajlı fiyatıyla FırsatKolik radarına takıldı.\n\n💡 Güncel stok durumu ve indirimden yararlanmak için hemen inceleyebilirsiniz.\n\n${brandFooter}`;
  }

  // 6. 1 Ağustos Ticari Reklam Yönetmeliği Uyum Etiketi (#tanıtım) ile sonlandır
  return advertisingComplianceService.ensureAdvertisingDisclosure(finalBody);
}

module.exports = {
  formatAndEnrichDescription,
  truncateEditorAndFooterInfo,
  isTruncationTriggerLine,
  isBarePriceLine,
  isDuplicateTitleLine,
  BRAND_HEADERS,
  BRAND_FOOTERS,
};
