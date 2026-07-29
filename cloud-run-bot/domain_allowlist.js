const fs = require('fs');
const path = require('path');

const candidatePaths = [
  path.join(__dirname, 'domain_allowlist_extended.json'),
  path.join(__dirname, '../assets/data/domain_allowlist_extended.json')
];

let allowlistConfig = null;
for (const p of candidatePaths) {
  try {
    if (fs.existsSync(p)) {
      const rawData = fs.readFileSync(p, 'utf8');
      allowlistConfig = JSON.parse(rawData);
      console.log(`✅ Domain Allowlist dinamik olarak yüklendi: ${p} (${Object.keys(allowlistConfig.stores || {}).length} mağaza)`);
      break;
    }
  } catch (err) {
    console.warn(`⚠️ Allowlist dosyası okunamadı (${p}): ${err.message}`);
  }
}

if (!allowlistConfig || !allowlistConfig.stores) {
  console.error('⚠️ Hiçbir domain allowlist JSON dosyası okunamadı, 20 mağazalık varsayılan fallback kullanılıyor.');
  allowlistConfig = {
    stores: {
      "trendyol": ["trendyol.com"],
      "hepsiburada": ["hepsiburada.com"],
      "amazon_tr": ["amazon.com.tr"],
      "n11": ["n11.com"],
      "pazarama": ["pazarama.com"],
      "idefix": ["idefix.com"],
      "pttavm": ["pttavm.com"],
      "teknosa": ["teknosa.com"],
      "mediamarkt_tr": ["mediamarkt.com.tr"],
      "vatan_bilgisayar": ["vatanbilgisayar.com"],
      "itopya": ["itopya.com"],
      "incehesap": ["incehesap.com"],
      "mavi": ["mavi.com"],
      "defacto_tr": ["defacto.com.tr"],
      "zara_tr": ["zara.com"],
      "mango_tr": ["mango.com"],
      "beymen": ["beymen.com"],
      "migros": ["migros.com.tr"],
      "getir": ["getir.com"],
      "havit_turkiye": ["havitstore.com.tr"]
    }
  };
}

const ALLOWED_DOMAINS = Object.values(allowlistConfig.stores).flat().map(d => d.toLowerCase());

/**
 * Verilen URL string'inin (veya hostname'inin) domain allowlist'te olup olmadığını kontrol eder.
 * Hostname exact match ("trendyol.com") veya subdomain match (".trendyol.com") olmalıdır.
 */
function isDomainAllowed(urlStr) {
  if (!urlStr || typeof urlStr !== 'string') return false;
  try {
    let urlObj;
    const trimmed = urlStr.trim();
    try {
      urlObj = new URL(trimmed);
    } catch (_) {
      urlObj = new URL('https://' + trimmed);
    }
    const host = urlObj.hostname.toLowerCase();
    if (!host) return false;

    for (const allowed of ALLOWED_DOMAINS) {
      if (host === allowed || host.endsWith('.' + allowed)) {
        return true;
      }
    }
  } catch (_) {
    return false;
  }
  return false;
}

/**
 * Verilen URL'e karşılık gelen mağaza adını döndürür
 */
function getStoreKeyForUrl(urlStr) {
  if (!urlStr || typeof urlStr !== 'string') return null;
  try {
    let urlObj;
    const trimmed = urlStr.trim();
    try {
      urlObj = new URL(trimmed);
    } catch (_) {
      urlObj = new URL('https://' + trimmed);
    }
    const host = urlObj.hostname.toLowerCase();
    if (!host) return null;

    for (const [storeKey, domains] of Object.entries(allowlistConfig.stores)) {
      for (const allowed of domains) {
        if (host === allowed || host.endsWith('.' + allowed)) {
          return storeKey;
        }
      }
    }
  } catch (_) {}
  return null;
}

module.exports = {
  allowlistConfig,
  ALLOWED_DOMAINS,
  isDomainAllowed,
  getStoreKeyForUrl
};
