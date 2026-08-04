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
      "havit_turkiye": ["havitstore.com.tr"],
      "boyner": ["boyner.com.tr"]
    }
  };
}

const ALLOWED_DOMAINS = Object.values(allowlistConfig.stores).flat().map(d => d.toLowerCase());

// Ürün sayfası regex kurallarını yükle
const PRODUCT_PATH_RULES = {};
if (allowlistConfig.product_path_rules) {
  for (const [storeKey, patterns] of Object.entries(allowlistConfig.product_path_rules)) {
    PRODUCT_PATH_RULES[storeKey] = patterns.map(p => new RegExp(p, 'i'));
  }
  console.log(`✅ Product Path Rules yüklendi: ${Object.keys(PRODUCT_PATH_RULES).length} mağaza kuralı`);
}

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

/**
 * Verilen URL'nin bir ürün sayfası olup olmadığını kontrol eder.
 * 
 * Çalışma mantığı:
 * 1. URL'den pathname çıkarılır
 * 2. storeKey tespit edilir (getStoreKeyForUrl)
 * 3. product_path_rules[storeKey] kuralları alınır
 * 4. Kural tanımlı DEĞİLSE (undefined) → BYPASS (izin ver)
 * 5. Kural boş diziyse ([]) → BYPASS (bilinçli bypass, izin ver)
 * 6. Kural varsa → pathname ANY regex ile eşleşiyor mu? Evet → ürün sayfası, Hayır → değil
 * 
 * @param {string} urlStr - Kontrol edilecek URL
 * @returns {boolean} true = ürün sayfası veya bypass, false = ürün sayfası değil
 */
function isProductUrl(urlStr) {
  if (!urlStr || typeof urlStr !== 'string') return false;
  try {
    let urlObj;
    const trimmed = urlStr.trim();
    try {
      urlObj = new URL(trimmed);
    } catch (_) {
      urlObj = new URL('https://' + trimmed);
    }

    const storeKey = getStoreKeyForUrl(trimmed);
    if (!storeKey) {
      // Allowlist'te domain bulunamadı, bu aşamaya gelmemeli ama güvenlik için false
      return false;
    }

    const rules = PRODUCT_PATH_RULES[storeKey];

    // Kural tanımlı değilse → BYPASS (tanımlanmamış mağaza, filtre yok)
    if (rules === undefined) {
      return true;
    }

    // Kural boş diziyse → BYPASS (bilinçli olarak filtresiz bırakılmış)
    if (rules.length === 0) {
      return true;
    }

    // Pathname'e regex uygula (query parametreleri ve hash hariç)
    const pathname = urlObj.pathname;
    for (const regex of rules) {
      if (regex.test(pathname)) {
        return true;
      }
    }

    // Hiçbir regex eşleşmedi → ürün sayfası değil
    return false;
  } catch (_) {
    return false;
  }
}

module.exports = {
  allowlistConfig,
  ALLOWED_DOMAINS,
  PRODUCT_PATH_RULES,
  isDomainAllowed,
  getStoreKeyForUrl,
  isProductUrl
};
