/**
 * FırsatKolik - Ticari Reklam Yönetmeliği Uyum Servisi
 * 
 * 1 Ağustos Ticari Reklam Yönetmeliği gereğince, indirim/fırsat platformlarında
 * paylaşılan affiliate ve tanıtım içeriklerinin #tanıtım etiketi ile
 * etiketlenmesini sağlar. Varsa eski reklam/işbirliği etiketlerini #tanıtım'a dönüştürür.
 */

// Tanınan reklam/tanıtım/işbirliği kalıpları (hashtag'li, parantezli veya köşeli)
const ADVERTISING_TAG_CLEANUP_REGEX = /(?:#|\[|\()(?:reklam|reklamdır|reklamdir|tanıtım|tanitim|işbirliği|isbirligi|sponsorlu|ortaklık|ortaklik|affiliate)(?:\]|\))?/gi;
const ADVERTISING_REGEX = /(?:#|\b)(?:reklam|reklamdır|reklamdir|tanıtım|tanitim|işbirliği|isbirligi|sponsorlu|ortaklık|ortaklik|affiliate)\b/i;

/**
 * Verilen metinde reklam/tanıtım/işbirliği etiketinin olup olmadığını kontrol eder.
 * @param {string} text 
 * @returns {boolean}
 */
function hasAdvertisingDisclosure(text) {
  if (!text || typeof text !== 'string') return false;
  
  const trimmed = text.trim();
  if (!trimmed) return false;

  const lowerStandard = trimmed.toLowerCase();
  const lowerTurkish = trimmed.toLocaleLowerCase('tr-TR');

  return ADVERTISING_REGEX.test(lowerStandard) || ADVERTISING_REGEX.test(lowerTurkish);
}

/**
 * Açıklama metnini normalize eder:
 * - Varsa eski #reklam, #işbirliği, [REKLAM] vb. etiketleri temizler.
 * - Metnin sonuna standart tek bir '#tanıtım' etiketi ekler.
 * 
 * @param {string} text - Orijinal açıklama metni
 * @param {string} defaultTag - Eklenecek standart etiket (Varsayılan: '#tanıtım')
 * @returns {string}
 */
function ensureAdvertisingDisclosure(text, defaultTag = '#tanıtım') {
  let safeText = (text || '').trim();

  // Eğer metin tamamen boşsa varsayılan açıklama + etiket dön
  if (!safeText) {
    return `Fırsat Ürünü Detayları\n\n${defaultTag}`;
  }

  // Varsa eski reklam/tanıtım/işbirliği etiketlerini kaldır
  safeText = safeText.replace(ADVERTISING_TAG_CLEANUP_REGEX, '').trim();
  safeText = safeText.replace(/\n{3,}/g, '\n\n').trim();

  if (!safeText) {
    return `Fırsat Ürünü Detayları\n\n${defaultTag}`;
  }

  // Sonuna standart #tanıtım etiketini ekle
  return `${safeText}\n\n${defaultTag}`;
}

module.exports = {
  hasAdvertisingDisclosure,
  ensureAdvertisingDisclosure,
  ADVERTISING_REGEX,
  ADVERTISING_TAG_CLEANUP_REGEX,
};
