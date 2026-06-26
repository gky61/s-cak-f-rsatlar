/**
 * Telegram Client API ile Kanal Mesajlarını Okuma
 * Yönetici olmadan public kanallardan mesaj çekmek için
 */

const {TelegramClient} = require('telegram');
const {StringSession} = require('telegram/sessions');
const admin = require('firebase-admin');
const cheerio = require('cheerio');

// Uygulama kategori ID'leri (Flutter Category.categories ile aynı)
const APP_CATEGORY_IDS = ['elektronik', 'moda', 'ev_yasam', 'anne_bebek', 'kozmetik', 'spor_outdoor', 'supermarket', 'yapi_oto', 'kitap_hobi', 'diger'];

// Bot keyword kategori ID → uygulama kategori ID
const BOT_TO_APP_CATEGORY = {
  bilgisayar: 'elektronik',
  mobil_cihazlar: 'elektronik',
  konsol_oyun: 'kitap_hobi',
  ev_elektronigi_yasam: 'ev_yasam',
  ag_yazilim: 'elektronik',
};

function normalizeBotCategoryToApp(botCategory) {
  if (!botCategory || typeof botCategory !== 'string') return 'diger';
  const lower = botCategory.trim().toLowerCase();
  if (APP_CATEGORY_IDS.includes(lower)) return lower;
  return BOT_TO_APP_CATEGORY[lower] || 'diger';
}

/**
 * Başlık elektronik ürün mü (laptop, PC, telefon, kasa vb.) - AI "diger" dönse bile düzeltmek için
 */
function titleSuggestsElectronics(title) {
  if (!title || typeof title !== 'string') return false;
  const t = title.toLowerCase();
  const keywords = [
    'asus', 'acer', 'lenovo', 'dell', 'msi', 'hp ', 'hp.', 'gaming', 'laptop', 'notebook', 'ultrabook', 'chromebook', 'macbook',
    'bilgisayar', 'monitör', 'monitor', 'kasa', 'ekran kartı', 'grafik kartı', 'gpu', 'cpu', 'işlemci', 'anakart', 'psu', 'güç kaynağı',
    'telefon', 'iphone', 'samsung', 'xiaomi', 'huawei', 'honor', 'oppo', 'realme', 'oneplus', 'poco', 'redmi', 'vivo',
    'tablet', 'ipad', 'galaxy tab', 'kulaklık', 'airpods', 'earbuds', 'tws', 'bluetooth kulaklık', 'hoparlör', 'speaker', 'soundbar',
    'tv ', 'televizyon', 'smart tv', 'robot süpürge', 'akıllı saat', 'smartwatch', 'apple watch', 'galaxy watch',
    'rtx', 'gtx', 'amd', 'intel', 'ryzen', 'core i', 'ram ', 'ssd', 'nvme', 'm.2', 'hdd', 'disk',
    'tuf ', 'rog ', 'a21', 'a32', 'a52', 'a72', 'galaxy a', 'galaxy s', 'redmi note', 'poco x', 'poco m',
    'playstation', 'xbox', 'nintendo', 'switch', 'steam deck', 'konsol', 'oyun konsolu',
    'kamera', 'fotoğraf makinesi', 'drone', 'webcam', 'yazıcı', 'printer', 'modem', 'router', 'mesh',
    'powerbank', 'power bank', 'şarj', 'sarj', 'şarj aleti', 'adaptör', 'type-c', 'usb-c', 'thunderbolt',
    'beyaz eşya', 'bulaşık makinesi', 'çamaşır makinesi', 'buzdolabı', 'fırın', 'mikrodalga', 'küçük ev aleti', 'airfryer', 'vantilatör', 'kahve makinesi',
    'hyperx', 'kulak üstü', 'oyuncu kulaklığı', 'gaming headset', 'cloud iii', 'kablosuz kulaklık',
  ];
  return keywords.some((kw) => t.includes(kw));
}

/** Başlık moda/giyim mi (ayakkabı, mont, tişört vb.) */
function titleSuggestsModa(title) {
  if (!title || typeof title !== 'string') return false;
  const t = title.toLowerCase();
  const keywords = ['ayakkabı', 'bot', 'sneaker', 'mont', 'ceket', 'tişört', 't-shirt', 'pantolon', 'elbise', 'çanta', 'çantası', 'saat', 'takı', 'sweatshirt', 'hoodie', 'şort', 'etek', 'kadın', 'erkek giyim', 'triko', 'kazak'];
  return keywords.some((kw) => t.includes(kw));
}

/** Başlık süpermarket/gıda mı */
function titleSuggestsSupermarket(title) {
  if (!title || typeof title !== 'string') return false;
  const t = title.toLowerCase();
  const keywords = ['gıda', 'yiyecek', 'içecek', 'deterjan', 'süt', 'peynir', 'zeytinyağı', 'makarna', 'konserve', 'çikolata', 'bisküvi', 'atıştırmalık', 'mama ', 'kedi', 'köpek maması', 'temizlik', 'kağıt havlu'];
  return keywords.some((kw) => t.includes(kw));
}

/** Başlık ev/yaşam/mobilya mı */
function titleSuggestsEvYasam(title) {
  if (!title || typeof title !== 'string') return false;
  const t = title.toLowerCase();
  const keywords = ['mobilya', 'koltuk', 'masa', 'yatak', 'dolap', 'mutfak', 'beyaz eşya', 'bulaşık', 'çamaşır makinesi', 'buzdolabı', 'fırın', 'dekorasyon', 'aydınlatma', 'perde', 'halı'];
  return keywords.some((kw) => t.includes(kw));
}

/**
 * Gemini AI ile ürün başlık/açıklamadan kategori tespit et.
 * @param {string} title - Ürün başlığı
 * @param {string} description - Ürün açıklaması (ilk ~500 karakter)
 * @param {string} apiKey - Gemini API key
 * @returns {Promise<string|null>} - Uygulama kategori ID'si veya null
 */
async function detectCategoryWithAI(title, description, apiKey) {
  if (!apiKey || !title) return null;
  const text = [title, (description || '').slice(0, 500)].filter(Boolean).join('\n');
  const prompt = `Urun kategorisi tespit et. SADECE asagidaki kodlardan BIRINI yaz, baska hicbir sey yazma.

Kodlar: elektronik, moda, ev_yasam, anne_bebek, kozmetik, spor_outdoor, kitap_hobi, yapi_oto, supermarket, diger

ELEKTRONIK (genis kapsam - siki uygula):
- Tum teknoloji ve elektrikli urunler = elektronik.
- Bilgisayar: laptop, notebook, PC, kasa, monitör, ekran karti, GPU, CPU, RAM, SSD, Asus, Acer, Dell, HP, Lenovo, MSI, Gaming, RTX, GTX, AMD, Intel, Chromebook, MacBook.
- Telefon/tablet: iPhone, Samsung, Xiaomi, Huawei, Honor, Oppo, Realme, OnePlus, Poco, Redmi, tablet, iPad, Galaxy Tab.
- TV/ses: televizyon, smart TV, kulaklik, AirPods, hoparlor, soundbar.
- Diger: robot supurge, akilli saat, smartwatch, modem, router, yazici, kamera, drone, webcam, powerbank, sarj aleti, oyun konsolu (PlayStation, Xbox, Nintendo, Switch).
- Beyaz esya ve kucuk ev aletleri (buzdolabi, firin, camasir/bulasik makinesi, airfryer, vantilator, kahve makinesi) = elektronik.
- Marka veya model adi (RTX, Galaxy, Redmi Note, TUF, ROG vb.) gecen urunler cogunlukla elektronik.
- Sadece "saat" (kol saati aksesuar) moda; "akilli saat/smartwatch" elektronik.

DIGER KATEGORILER:
- Giyim, ayakkabi, canta, elbise, mont, tisort, pantolon, taki (aksesuar), kiyafet → moda
- Mobilya, koltuk, masa, yatak, dolap, dekorasyon, aydinlatma, perde, halı, ev tekstili, kirtasiye → ev_yasam
- Bebek, biberon, mama, bebek bezi, oto koltugu → anne_bebek
- Krem, sampuan, makyaj, parfum, cilt bakim → kozmetik
- Spor, kamp, fitness, bisiklet, outdoor → spor_outdoor
- Kitap, dergi, gitar, piyano, hobi, sanat → kitap_hobi
- Oto, hirdavat, matkap, lastik, motor yagi → yapi_oto
- Gida, yiyecek, deterjan, temizlik, market → supermarket
- Belirsizse → diger

Urun metni:
${text}

Cevap (tek kelime, yukaridaki kodlardan biri):`;

  const models = ['gemini-1.5-flash', 'gemini-1.5-flash-latest', 'gemini-2.0-flash'];
  for (const model of models) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          contents: [{parts: [{text: prompt}]}],
          generationConfig: {temperature: 0.1, maxOutputTokens: 20},
        }),
      });
      if (!response.ok) {
        const errText = await response.text();
        if (response.status === 404) continue;
        console.log(`Gemini ${model} hata:`, response.status, errText.slice(0, 150));
        continue;
      }
      const data = await response.json();
      if (data?.error) {
        console.log(`Gemini ${model} error:`, data.error.message);
        continue;
      }
      const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '';
      // Boşlukları alt çizgi yap (Gemini "ev yasam" dönebilir), nokta/kalıntı temizle
      const category = raw.toLowerCase().replace(/\s+/g, '_').replace(/\./g, '').trim();
      if (APP_CATEGORY_IDS.includes(category)) return category;
      if (category === 'diger') return 'diger';
      console.log('Gemini gecersiz kategori:', raw);
      return null;
    } catch (e) {
      console.log(`Gemini ${model} exception:`, e.message);
      continue;
    }
  }
  return null;
}

// Firebase Admin'i başlat (eğer başlatılmamışsa)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ==================== YARDIMCI FONKSİYONLAR ====================

// ==================== GÖRSEL ÇEKME SİSTEMİ ====================

/**
 * Telegram media'dan görsel çek ve Firebase Storage'a yükle
 * @param {Object} client - Telegram client
 * @param {Object} message - Telegram message
 * @param {string} chatIdentifier - Chat identifier
 * @param {number} messageId - Message ID
 * @param {number} retries - Retry sayısı
 * @return {Promise<string|null>} - Görsel URL'i veya null
 */
async function fetchImageFromTelegramMedia(client, message, chatIdentifier, messageId, retries = 5) {
  if (!message.media) {
    console.log('ℹ️ Telegram mesajında media yok');
    return null;
  }

  const media = message.media;
  console.log(`📷 Telegram media tespit edildi: ${media.className}`);

  if (media.className !== 'MessageMediaPhoto') {
    console.log(`⚠️ Desteklenmeyen media tipi: ${media.className}`);
    return null;
  }

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      console.log(`📥 Telegram görsel indiriliyor (deneme ${attempt + 1}/${retries + 1})...`);

      let buffer = null;

      // Önce en büyük boyutu dene
      const downloadOptions = [
        {thumb: -1, label: 'en büyük boyut'},
        {thumb: 0, label: 'küçük boyut'},
        {}, // Varsayılan
      ];

      for (const option of downloadOptions) {
        try {
          buffer = await client.downloadMedia(message, option);
          if (buffer) {
            console.log(`✅ Görsel ${option.label || 'varsayılan'} ile indirildi`);
            break;
          }
        } catch (e) {
          console.log(`⚠️ ${option.label || 'Varsayılan'} ile indirme başarısız: ${e.message}`);
          continue;
        }
      }

      if (!buffer) {
        throw new Error('Görsel buffer alınamadı');
      }

      // Buffer'ı işle
      let imageBuffer;
      if (Buffer.isBuffer(buffer)) {
        imageBuffer = buffer;
      } else if (typeof buffer === 'string') {
        imageBuffer = Buffer.from(buffer, 'base64');
      } else if (buffer && buffer.constructor && buffer.constructor.name === 'Buffer') {
        imageBuffer = buffer;
      } else {
        imageBuffer = Buffer.from(buffer);
      }

      if (!imageBuffer || imageBuffer.length === 0) {
        throw new Error('Görsel buffer boş veya geçersiz');
      }

      // Minimum boyut kontrolü (1KB)
      if (imageBuffer.length < 1024) {
        throw new Error(`Görsel çok küçük: ${imageBuffer.length} bytes`);
      }

      // Görsel formatını kontrol et (magic bytes)
      const isValidImage = (imageBuffer[0] === 0xFF && imageBuffer[1] === 0xD8) || // JPEG
                          (imageBuffer[0] === 0x89 && imageBuffer[1] === 0x50 &&
                           imageBuffer[2] === 0x4E && imageBuffer[3] === 0x47) || // PNG
                          (imageBuffer[0] === 0x47 && imageBuffer[1] === 0x49 &&
                           imageBuffer[2] === 0x46); // GIF

      if (!isValidImage) {
        console.log('⚠️ Görsel formatı geçersiz, JPEG olarak kaydediliyor');
      }

      // Firebase Storage'a yükle
      const bucket = admin.storage().bucket();
      const timestamp = Date.now();
      const fileName = `telegram/${chatIdentifier}/${messageId}_${timestamp}.jpg`;
      const file = bucket.file(fileName);

      const stream = file.createWriteStream({
        metadata: {
          contentType: 'image/jpeg',
          metadata: {
            source: 'telegram',
            messageId: messageId.toString(),
            channel: chatIdentifier,
            timestamp: timestamp.toString(),
          },
        },
        public: true,
      });

      await new Promise((resolve, reject) => {
        stream.on('error', (err) => {
          console.error('❌ Stream hatası:', err);
          reject(err);
        });
        stream.on('finish', () => {
          console.log('✅ Stream tamamlandı');
          resolve();
        });
        stream.end(imageBuffer);
      });

      const imageUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;
      console.log(`✅ Telegram görsel başarıyla yüklendi: ${imageUrl} (${imageBuffer.length} bytes)`);
      return imageUrl;
    } catch (error) {
      console.error(`❌ Telegram görsel yükleme hatası (deneme ${attempt + 1}/${retries + 1}):`, error.message);
      if (attempt === retries) {
        console.error('❌ Tüm denemeler başarısız');
        return null;
      }
      // Kısa bir bekleme sonra tekrar dene
      await new Promise((resolve) => setTimeout(resolve, 1000 * (attempt + 1)));
    }
  }

  return null;
}

/**
 * Linkten görsel çek (çok kapsamlı)
 * @param {string} url - Link URL'i
 * @param {string} baseUrl - Base URL (resolve için)
 * @return {Promise<string|null>} - Görsel URL'i veya null
 */
async function fetchImageFromLink(url, baseUrl) {
  if (!url) return null;

  try {
    console.log(`🔗 Linkten görsel çekiliyor: ${url}`);
    const linkData = await fetchLinkData(url, 2);

    if (!linkData || !linkData.html) {
      console.log('⚠️ Link HTML çekilemedi');
      return null;
    }

    const $ = cheerio.load(linkData.html);
    const baseUrlObj = new URL(baseUrl);

    // Görsel arama öncelik sırası
    const imageSources = [];

    // 1. JSON-LD Schema (en güvenilir)
    const jsonLdImage = extractImageFromJsonLd(linkData.html, baseUrlObj);
    if (jsonLdImage) {
      imageSources.push({url: jsonLdImage, source: 'JSON-LD'});
    }

    // 2. Open Graph
    const ogImage = $('meta[property="og:image"]').attr('content') ||
                    $('meta[name="og:image"]').attr('content');
    if (ogImage && !ogImage.startsWith('blob:')) {
      imageSources.push({url: resolveUrl(ogImage, baseUrlObj), source: 'Open Graph'});
    }

    // 3. Twitter Card
    const twitterImage = $('meta[name="twitter:image"]').attr('content') ||
                         $('meta[property="twitter:image"]').attr('content');
    if (twitterImage && !twitterImage.startsWith('blob:')) {
      imageSources.push({url: resolveUrl(twitterImage, baseUrlObj), source: 'Twitter Card'});
    }

    // 4. Hepsiburada özel
    const hbImage = $('[data-image]').first().attr('data-image') ||
                    $('[data-srcset]').first().attr('data-srcset')?.split(',')[0]?.trim().split(' ')[0] ||
                    $('[data-original-src]').first().attr('data-original-src');
    if (hbImage && !hbImage.startsWith('blob:')) {
      imageSources.push({url: resolveUrl(hbImage, baseUrlObj), source: 'Hepsiburada'});
    }

    // 5. Itemprop image
    const itempropImage = $('[itemprop="image"]').attr('content') ||
                          $('[itemprop="image"]').attr('src') ||
                          $('img[itemprop="image"]').attr('src');
    if (itempropImage && !itempropImage.startsWith('blob:')) {
      imageSources.push({url: resolveUrl(itempropImage, baseUrlObj), source: 'Itemprop'});
    }

    // 6. Product image class'ları
    const productImg = $('img.product-image, img[class*="product"], ' +
        'img[class*="main"], img[class*="primary"], img[class*="hero"]')
        .not('[src*="icon"], [src*="logo"], [src*="placeholder"], [src*="avatar"]')
        .first()
        .attr('src');
    if (productImg && !productImg.startsWith('blob:')) {
      imageSources.push({url: resolveUrl(productImg, baseUrlObj), source: 'Product Image'});
    }

    // 7. İlk büyük img tag
    $('img').each((i, elem) => {
      if (imageSources.length > 0) return false;
      const src = $(elem).attr('src') || $(elem).attr('data-src') || $(elem).attr('data-lazy-src');
      if (src &&
          !src.startsWith('blob:') &&
          !src.includes('icon') &&
          !src.includes('logo') &&
          !src.includes('placeholder') &&
          !src.includes('avatar') &&
          (src.includes('http') || src.startsWith('/'))) {
        imageSources.push({url: resolveUrl(src, baseUrlObj), source: 'IMG Tag'});
        return false;
      }
    });

    // İlk geçerli görseli döndür
    for (const imgSource of imageSources) {
      if (imgSource.url && !imgSource.url.startsWith('blob:')) {
        console.log(`✅ Linkten görsel bulundu (${imgSource.source}): ${imgSource.url}`);
        return imgSource.url;
      }
    }

    console.log('⚠️ Linkten görsel bulunamadı');
    return null;
  } catch (error) {
    console.error('❌ Linkten görsel çekme hatası:', error.message);
    return null;
  }
}

// ==================== DİĞER YARDIMCI FONKSİYONLAR ====================

/**
 * Kısa linki takip edip son URL'yi döndürür (mağaza tespiti için).
 * @param {string} url - Başlangıç URL (kısa link olabilir)
 * @returns {Promise<string|null>} - Son URL veya null
 */
function resolveRedirectToFinalUrl(url) {
  const https = require('https');
  const http = require('http');
  const {URL} = require('url');

  return new Promise((resolve) => {
    try {
      const maxRedirects = 7;
      let redirectCount = 0;
      let currentUrl = url;

      function followRedirect(location) {
        if (redirectCount >= maxRedirects) {
          resolve(currentUrl);
          return;
        }
        redirectCount++;
        if (!location.startsWith('http://') && !location.startsWith('https://')) {
          const base = new URL(currentUrl);
          location = new URL(location, base.origin).toString();
        }
        currentUrl = location;
        const urlObj = new URL(location);
        const protocol = urlObj.protocol === 'https:' ? https : http;
        const options = {
          hostname: urlObj.hostname,
          port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
          path: urlObj.pathname + urlObj.search,
          method: 'HEAD',
          timeout: 8000,
          headers: {'User-Agent': 'Mozilla/5.0 (compatible; Bot/1.0)'},
        };
        const req = protocol.request(options, (res) => {
          if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
            followRedirect(res.headers.location);
          } else {
            resolve(currentUrl);
          }
        });
        req.on('error', () => resolve(currentUrl));
        req.on('timeout', () => { req.destroy(); resolve(currentUrl); });
        req.end();
      }

      const urlObj = new URL(currentUrl);
      const protocol = urlObj.protocol === 'https:' ? https : http;
      const options = {
        hostname: urlObj.hostname,
        port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
        path: urlObj.pathname + urlObj.search,
        method: 'HEAD',
        timeout: 8000,
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; Bot/1.0)'},
      };
      const req = protocol.request(options, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          followRedirect(res.headers.location);
        } else {
          resolve(currentUrl);
        }
      });
      req.on('error', () => resolve(url));
      req.on('timeout', () => { req.destroy(); resolve(url); });
      req.end();
    } catch (e) {
      resolve(url);
    }
  });
}

/**
 * URL hostname'den mağaza adı çıkar (Türk e-ticaret siteleri + kısa link sonrası).
 */
function storeFromHostname(hostname) {
  if (!hostname || typeof hostname !== 'string') return null;
  const h = hostname.replace(/^www\./, '').toLowerCase();
  if (h.includes('hepsiburada')) return 'Hepsiburada';
  if (h.includes('trendyol')) return 'Trendyol';
  if (h.includes('n11.')) return 'N11';
  if (h.includes('gittigidiyor')) return 'GittiGidiyor';
  if (h.includes('amazon')) return 'Amazon';
  if (h.includes('vatan')) return 'Vatan Bilgisayar';
  if (h.includes('mediamarkt')) return 'MediaMarkt';
  if (h.includes('teknosa')) return 'Teknosa';
  if (h.includes('akakce')) return 'Akakçe';
  if (h.includes('ciceksepeti')) return 'Çiçeksepeti';
  const first = h.split('.')[0];
  if (first) return first.charAt(0).toUpperCase() + first.slice(1);
  return null;
}

// URL'den HTML çek (retry ile)
async function fetchLinkData(url, retries = 2) {
  const https = require('https');
  const http = require('http');
  const {URL} = require('url');

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const urlObj = new URL(url);
      const protocol = urlObj.protocol === 'https:' ? https : http;

      const html = await new Promise((resolve, reject) => {
        let timeout = null;
        let htmlData = '';
        let resolved = false;

        const req = protocol.get(url, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ' +
                'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
            'Accept-Encoding': 'gzip, deflate, br',
            'Referer': urlObj.origin,
            'Connection': 'keep-alive',
          },
        }, (res) => {
          // Gzip desteği için zlib eklenebilir ama şimdilik basit tutuyoruz
          res.on('data', (chunk) => {
            if (resolved) return;
            htmlData += chunk.toString();
            // İlk 200KB yeterli (meta tag'ler ve JSON-LD genelde başta)
            if (htmlData.length > 200000) {
              res.destroy();
              if (timeout) clearTimeout(timeout);
              resolved = true;
              resolve(htmlData);
            }
          });

          res.on('end', () => {
            if (resolved) return;
            if (timeout) clearTimeout(timeout);
            resolved = true;
            resolve(htmlData);
          });
        });

        req.on('error', (err) => {
          if (resolved) return;
          if (timeout) clearTimeout(timeout);
          resolved = true;
          reject(err);
        });

        timeout = setTimeout(() => {
          if (resolved) return;
          resolved = true;
          req.destroy();
          reject(new Error('Request timeout'));
        }, 10000); // 10 saniye timeout
      });

      return {html: html};
    } catch (error) {
      console.log(`⚠️ Link çekme denemesi ${attempt + 1}/${retries + 1} başarısız: ${error.message}`);
      if (attempt === retries) {
        return {html: null};
      }
      // Kısa bir bekleme sonra tekrar dene
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
  return {html: null};
}

// JSON-LD'den görsel çıkar
function extractImageFromJsonLd(html, baseUrl) {
  try {
    const jsonLdPattern = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
    const jsonLdMatches = html.match(jsonLdPattern);

    if (!jsonLdMatches) return null;

    for (const jsonLdScript of jsonLdMatches) {
      try {
        const jsonContent = jsonLdScript.replace(/<script[^>]*>|<\/script>/gi, '').trim();
        const jsonData = JSON.parse(jsonContent);

        const findImage = (obj) => {
          if (typeof obj !== 'object' || obj === null) return null;

          if (obj.image) {
            if (typeof obj.image === 'string') {
              return obj.image;
            } else if (obj.image.url) {
              return obj.image.url;
            } else if (Array.isArray(obj.image) && obj.image.length > 0) {
              return typeof obj.image[0] === 'string' ? obj.image[0] : obj.image[0].url;
            }
          }
          if (obj.imageUrl) return obj.imageUrl;
          if (obj.thumbnailUrl) return obj.thumbnailUrl;
          if (obj.contentUrl) return obj.contentUrl;
          if (obj.photo) return typeof obj.photo === 'string' ? obj.photo : obj.photo.url;

          for (const key in obj) {
            if (Object.prototype.hasOwnProperty.call(obj, key)) {
              const result = findImage(obj[key]);
              if (result) return result;
            }
          }
          return null;
        };

        const foundImage = findImage(jsonData);
        if (foundImage && !foundImage.startsWith('blob:')) {
          return resolveUrl(foundImage, baseUrl);
        }
      } catch (e) {
        // JSON parse hatası, devam et
      }
    }
  } catch (e) {
    // Hata durumunda null dön
  }
  return null;
}

// JSON-LD'den fiyat çıkar
function extractPriceFromJsonLd(html) {
  try {
    const jsonLdPattern = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
    const jsonLdMatches = html.match(jsonLdPattern);

    if (!jsonLdMatches) return null;

    for (const jsonLdScript of jsonLdMatches) {
      try {
        const jsonContent = jsonLdScript.replace(/<script[^>]*>|<\/script>/gi, '').trim();
        const jsonData = JSON.parse(jsonContent);

        const findPrice = (obj) => {
          if (typeof obj !== 'object' || obj === null) return null;

          if (obj.price !== undefined) {
            const price = parsePrice(obj.price);
            if (price > 0) return price;
          }
          if (obj.offers) {
            if (obj.offers.price !== undefined) {
              const price = parsePrice(obj.offers.price);
              if (price > 0) return price;
            }
            if (obj.offers.lowPrice !== undefined) {
              const price = parsePrice(obj.offers.lowPrice);
              if (price > 0) return price;
            }
            if (obj.offers.highPrice !== undefined) {
              const price = parsePrice(obj.offers.highPrice);
              if (price > 0) return price;
            }
          }
          if (obj.lowPrice !== undefined) {
            const price = parsePrice(obj.lowPrice);
            if (price > 0) return price;
          }
          if (obj.highPrice !== undefined) {
            const price = parsePrice(obj.highPrice);
            if (price > 0) return price;
          }

          for (const key in obj) {
            if (Object.prototype.hasOwnProperty.call(obj, key)) {
              const result = findPrice(obj[key]);
              if (result !== null) return result;
            }
          }
          return null;
        };

        const foundPrice = findPrice(jsonData);
        if (foundPrice !== null) {
          return foundPrice;
        }
      } catch (e) {
        // JSON parse hatası, devam et
      }
    }
  } catch (e) {
    // Hata durumunda null dön
  }
  return null;
}

// Relative URL'yi absolute URL'ye çevir
function resolveUrl(url, baseUrl) {
  if (!url) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  if (url.startsWith('//')) {
    return baseUrl.protocol + url;
  }
  if (url.startsWith('/')) {
    return baseUrl.origin + url;
  }
  return baseUrl.origin + '/' + url;
}

// Fiyat string'ini parse et (çok kapsamlı)
function parsePrice(priceStr) {
  if (!priceStr) return 0;

  // String'e çevir
  let str = String(priceStr).trim();

  // TL, ₺, lira gibi sembolleri kaldır
  str = str.replace(/(?:₺|TL|lira|TRY|'ye|'a)/gi, '').trim();

  // Sadece rakam, nokta, virgül ve boşluk bırak
  str = str.replace(/[^\d.,\s]/g, '');

  // Boşlukları kaldır
  str = str.replace(/\s/g, '');

  if (!str) return 0;

  // Türk formatı kontrolü: "1.859,12" (nokta binlik, virgül ondalık)
  if (str.includes(',') && str.includes('.')) {
    // Virgülden sonra 2 rakam varsa Türk formatı
    const parts = str.split(',');
    if (parts.length === 2 && parts[1].length <= 2) {
      // Türk formatı: noktaları kaldır, virgülü noktaya çevir
      str = str.replace(/\./g, '').replace(',', '.');
    } else {
      // İngiliz formatı: virgülleri kaldır
      str = str.replace(/,/g, '');
    }
  } else if (str.includes(',')) {
    // Sadece virgül var - ondalık mı binlik mi kontrol et
    const parts = str.split(',');
    if (parts.length === 2 && parts[1].length <= 2) {
      // Ondalık olarak kabul et
      str = str.replace(',', '.');
    } else {
      // Binlik ayırıcı olarak kabul et
      str = str.replace(/,/g, '');
    }
  } else {
    // Sadece nokta var veya hiçbiri yok
    // Noktaları kaldır (binlik ayırıcı olarak kabul et)
    str = str.replace(/\./g, '');
  }

  const price = parseFloat(str);
  if (isNaN(price) || price <= 0 || price > 10000000) {
    return 0;
  }

  return price;
}

// ==================== TELEGRAM MESAJ PARSING ====================

// Telegram mesajını parse et (mevcut fonksiyon)
// Not: Fiyat artık linkten çekilecek, bu fonksiyon sadece fallback için
function parseTelegramMessage(messageText, messageEntities = [], buttonUrls = []) {
  const deal = {
    title: '',
    price: 0, // Varsayılan 0, linkten çekilecek
    store: '',
    category: '', // Boş bırak; anahtar kelime/AI ile doldurulacak, yoksa 'diger'
    link: '',
    imageUrl: '',
    description: '',
  };

  // URL'leri bul (öncelik sırası: butonlar > entities > text)
  const urls = [];

  // 1. Buton URL'lerini ekle (en öncelikli)
  urls.push(...buttonUrls);

  // 2. Entity URL'lerini ekle
  messageEntities.forEach((entity) => {
    if (entity.className === 'MessageEntityUrl' || entity.className === 'MessageEntityTextUrl') {
      const url = entity.className === 'MessageEntityUrl' ?
        messageText.substring(entity.offset, entity.offset + entity.length) :
        entity.url;
      if (url && !urls.includes(url)) {
        urls.push(url);
      }
    }
  });

  // 3. Text'ten URL'leri bul
  const urlRegex = /(https?:\/\/[^\s]+)/g;
  const textUrls = messageText.match(urlRegex) || [];
  textUrls.forEach((url) => {
    if (!urls.includes(url)) {
      urls.push(url);
    }
  });

  if (urls.length > 0) {
    deal.link = urls[0];
  }

  // Fiyat bul - Gelişmiş parsing (çeşitli formatlar)
  // Örnekler: "32.999TL", "32,999 TL", "32.999₺", "32 999 TL", "1.859,12 TL", "Toplam 1.779,00 TL"
  const pricePatterns = [
    // "Toplam 1.779,00 TL" formatı (öncelikli)
    /(?:toplam|total|fiyat|price|ücret)[\s:]+(\d{1,3}(?:\.\d{3})*(?:,\d{2})?|\d{1,3}(?:,\d{3})*(?:\.\d{2})?)/i,
    // "1.859,12 TL" formatı (Türk formatı: nokta binlik, virgül ondalık)
    /(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)\s*(?:TL|₺)/i,
    // "32.999TL" veya "32,999 TL" formatı
    /(\d{1,3}(?:[.,\s]\d{3})*(?:[.,]\d{2})?)\s*(?:TL|₺|lira|'ye|'a)/i,
    // "₺32.999" formatı
    /(?:₺|TL)\s*(\d{1,3}(?:[.,\s]\d{3})*(?:[.,]\d{2})?)/i,
  ];

  for (const pattern of pricePatterns) {
    const match = messageText.match(pattern);
    if (match) {
      let priceStr = match[1].trim();

      // Türk formatı kontrolü: "1.859,12" (nokta binlik, virgül ondalık)
      if (priceStr.includes(',') && priceStr.includes('.')) {
        // Virgülden sonra 2 rakam varsa Türk formatı
        const parts = priceStr.split(',');
        if (parts.length === 2 && parts[1].length <= 2) {
          // Türk formatı: noktaları kaldır, virgülü noktaya çevir
          priceStr = priceStr.replace(/\./g, '').replace(',', '.');
        } else {
          // İngiliz formatı: virgülleri kaldır
          priceStr = priceStr.replace(/,/g, '');
        }
      } else if (priceStr.includes(',')) {
        // Sadece virgül var - ondalık mı binlik mi kontrol et
        const parts = priceStr.split(',');
        if (parts.length === 2 && parts[1].length <= 2) {
          // Ondalık olarak kabul et
          priceStr = priceStr.replace(',', '.');
        } else {
          // Binlik ayırıcı olarak kabul et
          priceStr = priceStr.replace(/,/g, '');
        }
      } else {
        // Sadece nokta var veya hiçbiri yok
        // Noktaları kaldır (binlik ayırıcı olarak kabul et)
        priceStr = priceStr.replace(/\./g, '');
      }

      // Boşlukları kaldır
      priceStr = priceStr.replace(/\s/g, '');

      const price = parseFloat(priceStr);
      if (!isNaN(price) && price > 0) {
        deal.price = price;
        console.log(`💰 Fiyat bulundu: ${match[1]} -> ${price} TL`);
        break;
      }
    }
  }

  // Mağaza bul - İyileştirilmiş parsing
  const storePatterns = [
    /(?:mağaza|store|satıcı|seller|site|siteden)[\s:]+([^\n]+)/i,
    /(?:hepsiburada|trendyol|n11|gittigidiyor|amazon|vatan|mediamarkt|teknosa)/i,
  ];

  let storeFound = false;
  for (const pattern of storePatterns) {
    const match = messageText.match(pattern);
    if (match) {
      if (match[1]) {
        deal.store = match[1].trim().split('\n')[0].split(',')[0].trim();
        if (deal.store.length > 50) {
          deal.store = deal.store.substring(0, 47) + '...';
        }
      } else {
        // Direkt mağaza ismi bulundu
        const storeName = match[0].toLowerCase();
        if (storeName.includes('hepsiburada')) {
          deal.store = 'Hepsiburada';
        } else if (storeName.includes('trendyol')) {
          deal.store = 'Trendyol';
        } else if (storeName.includes('n11')) {
          deal.store = 'N11';
        } else if (storeName.includes('gittigidiyor')) {
          deal.store = 'GittiGidiyor';
        } else if (storeName.includes('amazon')) {
          deal.store = 'Amazon';
        } else if (storeName.includes('vatan')) {
          deal.store = 'Vatan Bilgisayar';
        } else if (storeName.includes('mediamarkt')) {
          deal.store = 'MediaMarkt';
        } else if (storeName.includes('teknosa')) {
          deal.store = 'Teknosa';
        }
      }
      storeFound = true;
      break;
    }
  }

  // URL'den domain adını al (son çare) - storeFromHostname ile tutarlı isim
  if (!storeFound && deal.link) {
    try {
      const url = new URL(deal.link);
      const hostname = url.hostname.replace('www.', '');
      const fromHost = storeFromHostname(hostname);
      deal.store = fromHost || (hostname.split('.')[0]
          ? hostname.split('.')[0].charAt(0).toUpperCase() + hostname.split('.')[0].slice(1)
          : 'Bilinmeyen Mağaza');
    } catch (e) {
      deal.store = 'Bilinmeyen Mağaza';
    }
  }

  if (!deal.store) {
    deal.store = 'Bilinmeyen Mağaza';
  }

  // Başlık bul - İyileştirilmiş parsing
  const lines = messageText.split('\n').filter((line) => line.trim());
  if (lines.length > 0) {
    let title = lines[0].trim();

    // URL'leri kaldır
    title = title.replace(urlRegex, '').trim();

    // Emoji ve özel karakterleri temizle (opsiyonel, daha temiz görünüm için)
    // title = title.replace(/[^\w\s-]/g, '').trim(); // Sadece harf, rakam, boşluk, tire

    // Çok uzun başlıkları kısalt
    if (title.length > 100) {
      title = title.substring(0, 97) + '...';
    }

    // Boşsa bir sonraki satırı dene
    if (title.length < 3 && lines.length > 1) {
      title = lines[1].trim().replace(urlRegex, '').trim();
      if (title.length > 100) {
        title = title.substring(0, 97) + '...';
      }
    }

    deal.title = title || 'Fırsat';
  }

  // Kategori bul: uygulama kategori ID'leri + anahtar kelimeler. UZUN ifadeler önce kontrol edilir (örn. "akıllı saat" moda "saat"ten önce).
  const categoryKeywords = {
    elektronik: [
      'akıllı saat', 'smartwatch', 'robot süpürge', 'ekran kartı', 'grafik kartı', 'bilgisayar', 'beyaz eşya', 'çamaşır makinesi', 'bulaşık makinesi', 'buzdolabı', 'küçük ev aleti', 'kahve makinesi', 'airfryer', 'power bank', 'powerbank', 'şarj aleti', 'bluetooth kulaklık',
      'kulak üstü', 'oyuncu kulaklığı', 'gaming headset', 'kablosuz kulaklık', 'hyperx', 'cloud iii',
      'laptop', 'notebook', 'ultrabook', 'chromebook', 'macbook', 'tablet', 'ipad', 'telefon', 'iphone', 'samsung', 'xiaomi', 'huawei', 'honor', 'oppo', 'realme', 'oneplus', 'poco', 'redmi',
      'pc ', 'gpu', 'cpu', 'işlemci', 'ram ', 'ssd', 'nvme', 'monitör', 'monitor', 'tv ', 'televizyon', 'smart tv', 'kulaklık', 'airpods', 'hoparlör', 'speaker', 'modem', 'router', 'yazıcı', 'webcam', 'kamera', 'drone',
      'asus', 'acer', 'dell', 'lenovo', 'msi', 'hp ', 'rtx', 'gtx', 'amd', 'intel', 'playstation', 'xbox', 'nintendo', 'switch', 'oyun konsolu', 'yazılım', 'antivirüs', 'akıllı ev', 'smart home',
    ],
    moda: ['giyim', 'ayakkabı', 'çanta', 'elbise', 'mont', 'tişört', 'pantolon', 'sweatshirt', 'kıyafet', 'takı', 'saat', 'aksesuar', 'erkek', 'kadın', 'çocuk giyim', 'spor ayakkabı', 'bot', 'ceket', 'şort', 'etek'],
    ev_yasam: ['mobilya', 'mutfak', 'dekorasyon', 'beyaz eşya', 'bulaşık makinesi', 'çamaşır', 'buzdolabı', 'fırın', 'koltuk', 'masa', 'yatak', 'dolap', 'aydınlatma', 'perde', 'halı', 'ev tekstili', 'kırtasiye', 'ofis'],
    anne_bebek: ['bebek', 'biberon', 'mama', 'bebek bezi', 'ıslak mendil', 'bebek arabası', 'oto koltuğu', 'emzirme', 'oyuncak bebek', 'çocuk'],
    kozmetik: ['krem', 'şampuan', 'makyaj', 'parfüm', 'deodorant', 'ruj', 'fondöten', 'cilt bakım', 'saç bakım', 'diş macunu', 'fırça', 'nemlendirici', 'güneş kremi'],
    spor_outdoor: ['spor', 'kamp', 'fitness', 'bisiklet', 'koşu', 'yürüyüş', 'outdoor', 'çadır', 'uyku tulumu', 'matara', 'spor ayakkabı', 'trikot', 'dambıl'],
    supermarket: ['gıda', 'yiyecek', 'içecek', 'deterjan', 'temizlik', 'kağıt havlu', 'tuvalet kağıdı', 'süt', 'peynir', 'zeytinyağı', 'makarna', 'konserve', 'meyve', 'sebze', 'atıştırmalık', 'mama', 'kedi', 'köpek maması'],
    yapi_oto: ['hırdavat', 'matkap', 'tornavida', 'oto', 'araba', 'lastik', 'motor yağı', 'elektrikli alet', 'bahçe', 'tesisat', 'banyo', 'lavabo'],
    kitap_hobi: ['kitap', 'dergi', 'müzik', 'gitar', 'piyano', 'konsol', 'playstation', 'xbox', 'nintendo', 'oyun', 'hobi', 'sanat', 'boya', 'puzzle'],
  };

  // En uzun anahtar kelime eşleşmesi kazanır (örn. "akıllı saat" elektronik, "saat" moda - metinde "akıllı saat" varsa elektronik seçilsin)
  const lowerText = messageText.toLowerCase();
  const allMatches = [];
  for (const [categoryId, keywords] of Object.entries(categoryKeywords)) {
    for (const keyword of keywords) {
      if (lowerText.includes(keyword)) {
        allMatches.push({ categoryId, keyword, len: keyword.length });
      }
    }
  }
  if (allMatches.length > 0) {
    allMatches.sort((a, b) => b.len - a.len);
    deal.category = allMatches[0].categoryId;
  }

  deal.description = messageText;
  return deal;
}

// Kanal mesajlarını çek ve Firestore'a kaydet
// options: { geminiApiKey?: string } - Gemini API key varsa AI ile kategori tespit edilir
async function fetchChannelMessages(channelUsername, apiId, apiHash, sessionString, options = {}) {
  const stringSession = new StringSession(sessionString || '');

  const client = new TelegramClient(stringSession, parseInt(apiId), apiHash, {
    connectionRetries: 5,
    timeout: 10000, // 10 saniye timeout
    retryDelay: 2000, // 2 saniye bekle
    autoReconnect: true,
  });

  try {
    await client.connect();
    console.log('Telegram Client bağlandı');

    // Kanal/Grup'u bul (username veya ID ile)
    let channel;
    try {
      // Önce username olarak dene
      if (channelUsername.startsWith('@')) {
        channel = await client.getEntity(channelUsername);
      } else if (channelUsername.startsWith('-')) {
        // Negatif sayı = Grup ID
        // Telegram'da grup ID'leri farklı formatlarda olabilir
        const numericId = parseInt(channelUsername);

        // Önce sayısal ID olarak dene
        try {
          channel = await client.getEntity(numericId);
        } catch (e1) {
          // Eğer -100 ile başlamıyorsa, supergroup formatına çevir
          if (!channelUsername.startsWith('-100')) {
            try {
              const numericPart = channelUsername.replace('-', '');
              const supergroupId = parseInt('-100' + numericPart);
              channel = await client.getEntity(supergroupId);
            } catch (e2) {
              // Son çare: InputPeerChat kullan
              const {Api} = require('telegram/tl');
              const chatId = Math.abs(numericId);
              const inputPeer = new Api.InputPeerChat({chatId: chatId});
              channel = await client.getEntity(inputPeer);
            }
          } else {
            throw e1;
          }
        }
      } else {
        // Sayısal ID veya username
        const numericId = parseInt(channelUsername);
        if (!isNaN(numericId) && numericId.toString() === channelUsername) {
          // Tam sayı ise ID olarak kullan
          channel = await client.getEntity(numericId);
        } else {
          // Username olarak dene (@ olmadan)
          channel = await client.getEntity('@' + channelUsername);
        }
      }
    } catch (error) {
      console.error('Kanal/Grup bulunamadı:', channelUsername, error.message);
      // Hata fırlatma, sadece logla ve devam et
      throw new Error(`Kanal/Grup bulunamadı: ${channelUsername} - ${error.message}`);
    }

    console.log('Kanal/Grup bulundu:', channel.title || channelUsername);

    // Son mesajları al (son 20 mesaj)
    const messages = await client.getMessages(channel, {
      limit: 20,
    });

    console.log(`${messages.length} mesaj bulundu`);

    const newDeals = [];

    for (const message of messages) {
      if (!message.message) continue;

      const messageText = message.message;
      const messageId = message.id;

      // Debug: Mesaj bilgilerini logla
      console.log(`\n📨 Mesaj ${messageId} işleniyor...`);
      console.log(`   Media var mı: ${!!message.media}`);
      if (message.media) {
        console.log(`   Media tipi: ${message.media.className}`);
      }

      // Reply markup'dan (butonlardan) URL'leri çıkar
      const buttonUrls = [];
      if (message.replyMarkup) {
        try {
          if (message.replyMarkup.className === 'ReplyInlineMarkup') {
            for (const row of message.replyMarkup.rows || []) {
              for (const button of row.buttons || []) {
                if (button.className === 'KeyboardButtonUrl') {
                  buttonUrls.push(button.url);
                } else if (button.className === 'KeyboardButtonCallback' && button.data) {
                  // Callback button'ları atla
                }
              }
            }
          }
        } catch (e) {
          console.log('Reply markup parse hatası:', e.message);
        }
      }

      // Bu mesajı daha önce işledik mi kontrol et
      const chatIdentifier = channelUsername.startsWith('@') ?
          channelUsername.replace('@', '') : channelUsername;
      const existingDeal = await db.collection('deals')
          .where('telegramMessageId', '==', messageId)
          .where('telegramChatUsername', '==', chatIdentifier)
          .limit(1)
          .get();

      if (!existingDeal.empty) {
        console.log(`Mesaj ${messageId} zaten işlenmiş, atlanıyor`);
        continue;
      }

      // Mesajı parse et (buton URL'lerini de ekle)
      const parsedDeal = parseTelegramMessage(messageText, message.entities || [], buttonUrls);

      // Mağaza bulunamadıysa veya link kısa linkse, son URL'den mağaza tespit et (örn. bit.ly → hepsiburada.com)
      const shortLinkHosts = ['bit.ly', 'bitly', 't.co', 'tinyurl', 'goo.gl', 'ow.ly', 'is.gd', 'buff.ly', 'adf.ly', 'tr.link'];
      let linkHost = '';
      try {
        linkHost = parsedDeal.link ? new URL(parsedDeal.link).hostname.replace('www.', '').toLowerCase() : '';
      } catch (_) {}
      const isShortLink = shortLinkHosts.some((h) => linkHost.includes(h));
      const storeMissing = !parsedDeal.store || parsedDeal.store === 'Bilinmeyen Mağaza' || isShortLink;
      if (storeMissing && parsedDeal.link) {
        try {
          const finalUrl = await resolveRedirectToFinalUrl(parsedDeal.link);
          if (finalUrl) {
            const {URL: UrlClass} = require('url');
            const hostname = new UrlClass(finalUrl).hostname.replace('www.', '');
            const storeFromUrl = storeFromHostname(hostname);
            if (storeFromUrl) {
              parsedDeal.store = storeFromUrl;
              console.log('📌 Mağaza URL çözümüyle tespit edildi:', parsedDeal.store, isShortLink ? '(kısa link)' : '');
            }
          }
        } catch (e) {
          console.log('⚠️ Kısa link çözümleme (mağaza) hatası:', e.message);
        }
      }

      // Kategori: Önce Gemini AI, yoksa keyword → uygulama ID. Asla boş veya yanlış "diger" kalmasın.
      if (options.geminiApiKey) {
        const aiCategory = await detectCategoryWithAI(
          parsedDeal.title,
          (parsedDeal.description || '').slice(0, 500),
          options.geminiApiKey,
        );
        parsedDeal.category = aiCategory || normalizeBotCategoryToApp(parsedDeal.category);
        if (aiCategory) console.log('🤖 AI kategori:', aiCategory);
      } else {
        parsedDeal.category = normalizeBotCategoryToApp(parsedDeal.category);
      }
      // Başlık veya mesaj metninden kategori düzeltmesi (ürün adı 2. satırda olsa bile metinde varsa yakala)
      const titleAndBody = [parsedDeal.title, (parsedDeal.description || '').slice(0, 600)].filter(Boolean).join(' ');
      if ((titleSuggestsElectronics(parsedDeal.title) || titleSuggestsElectronics(titleAndBody)) && (parsedDeal.category === 'diger' || parsedDeal.category === 'kitap_hobi')) {
        parsedDeal.category = 'elektronik';
        console.log('📌 Elektronik düzeltmesi (başlık/metin):', (parsedDeal.title || titleAndBody).slice(0, 50));
      } else if ((titleSuggestsModa(parsedDeal.title) || titleSuggestsModa(titleAndBody)) && parsedDeal.category === 'diger') {
        parsedDeal.category = 'moda';
        console.log('📌 Moda düzeltmesi (başlık/metin):', (parsedDeal.title || titleAndBody).slice(0, 50));
      } else if ((titleSuggestsSupermarket(parsedDeal.title) || titleSuggestsSupermarket(titleAndBody)) && parsedDeal.category === 'diger') {
        parsedDeal.category = 'supermarket';
        console.log('📌 Supermarket düzeltmesi (başlık/metin):', (parsedDeal.title || titleAndBody).slice(0, 50));
      } else if ((titleSuggestsEvYasam(parsedDeal.title) || titleSuggestsEvYasam(titleAndBody)) && parsedDeal.category === 'diger') {
        parsedDeal.category = 'ev_yasam';
        console.log('📌 Ev_yasam düzeltmesi (başlık/metin):', (parsedDeal.title || titleAndBody).slice(0, 50));
      }
      if (!parsedDeal.category) parsedDeal.category = 'diger';

      // Gerekli alanları kontrol et
      if (!parsedDeal.title || !parsedDeal.link) {
        console.log(`Mesaj ${messageId} eksik bilgi içeriyor, atlanıyor`);
        continue;
      }

      // Blob URL kontrolü - Mesaj metninde veya entities'te blob URL var mı?
      const hasBlobUrl = messageText.includes('blob:') ||
                         (message.entities && message.entities.some((entity) => {
                           if (entity.className === 'MessageEntityUrl' || entity.className === 'MessageEntityTextUrl') {
                             const url = entity.className === 'MessageEntityUrl' ?
                               messageText.substring(entity.offset, entity.offset + entity.length) :
                               entity.url;
                             return url && url.startsWith('blob:');
                           }
                           return false;
                         }));

      if (hasBlobUrl) {
        console.log('⚠️ Mesajda blob URL tespit edildi - Telegram media\'dan görsel çekme zorunlu');
      }

      // GÖRSEL ÇEKME - Yeni modüler sistem
      // Eğer blob URL varsa, Telegram media'dan çekmeyi zorunlu hale getir
      console.log('\n🖼️ Görsel çekme işlemi başlatılıyor...');
      let imageUrl = '';

      // Blob URL varsa veya media varsa, önce Telegram media'dan çek
      if (hasBlobUrl || message.media) {
        console.log('📷 Telegram media\'dan görsel çekiliyor ' +
            '(blob URL tespit edildi veya media var)...');
        const telegramImage = await fetchImageFromTelegramMedia(
            client, message, chatIdentifier, messageId, 5); // 5 retry
        if (telegramImage) {
          imageUrl = telegramImage;
          console.log('✅ Telegram media\'dan görsel başarıyla çekildi');
        } else {
          console.log('⚠️ Telegram media\'dan görsel çekilemedi, linkten deneniyor...');
        }
      }

      // Telegram media'dan çekilemediyse, linkten çek (fetchDealImage sadece linkten çeker)
      if (!imageUrl || imageUrl === '') {
        if (parsedDeal.link) {
          console.log('🔗 Linkten görsel çekiliyor...');
          const linkImage = await fetchImageFromLink(parsedDeal.link, parsedDeal.link);
          if (linkImage) {
            imageUrl = linkImage;
            console.log('✅ Linkten görsel başarıyla çekildi');
          } else {
            console.log('⚠️ Linkten görsel çekilemedi');
          }
        }
      }

      console.log(`🖼️ Görsel çekme sonucu: ${imageUrl || 'Görsel bulunamadı'}\n`);

      // FİYAT ÇEKME - Linkten
      let priceFromLink = null;
      if (parsedDeal.link) {
        try {
          console.log('💰 Linkten fiyat çekiliyor: ' + parsedDeal.link);
          const linkData = await fetchLinkData(parsedDeal.link, 2);

          if (linkData && linkData.html) {
            const $ = cheerio.load(linkData.html);

            // Öncelik 1: JSON-LD Schema (en güvenilir)
            priceFromLink = extractPriceFromJsonLd(linkData.html);
            if (priceFromLink) {
              console.log('✅ Fiyat bulundu (JSON-LD): ' + priceFromLink);
            }

            // Öncelik 2: Meta tags
            if (!priceFromLink) {
              const priceMeta = $('meta[property="product:price:amount"]').attr('content') ||
                                $('meta[name="price"]').attr('content') ||
                                $('meta[itemprop="price"]').attr('content');
              if (priceMeta) {
                const price = parsePrice(priceMeta);
                if (price > 0) {
                  priceFromLink = price;
                  console.log('✅ Fiyat bulundu (Meta): ' + priceFromLink);
                }
              }
            }

            // Öncelik 3: Data attributes
            if (!priceFromLink) {
              const dataPrice = $('[data-price]').first().attr('data-price') ||
                                $('[data-product-price]').first().attr('data-product-price');
              if (dataPrice) {
                const price = parsePrice(dataPrice);
                if (price > 0) {
                  priceFromLink = price;
                  console.log('✅ Fiyat bulundu (Data attr): ' + priceFromLink);
                }
              }
            }

            // Öncelik 4: Itemprop price
            if (!priceFromLink) {
              const itempropPrice = $('[itemprop="price"]').attr('content') ||
                                    $('[itemprop="price"]').text();
              if (itempropPrice) {
                const price = parsePrice(itempropPrice);
                if (price > 0) {
                  priceFromLink = price;
                  console.log('✅ Fiyat bulundu (itemprop): ' + priceFromLink);
                }
              }
            }

            // Öncelik 5: Site-özel fiyat selector'ları
            if (!priceFromLink) {
              const urlObj = new URL(parsedDeal.link);
              const hostname = urlObj.hostname.toLowerCase();

              // Trendyol özel selector'ları
              if (hostname.includes('trendyol')) {
                console.log('🔍 Trendyol fiyat selector\'ları deneniyor...');

                // Önce script tag'lerinde fiyat ara (window.__INITIAL_STATE__ veya benzeri)
                const scriptTags = $('script').toArray();
                for (const script of scriptTags) {
                  const scriptContent = $(script).html() || '';
                  // window.__INITIAL_STATE__ veya benzeri JSON objelerinde fiyat ara
                  const priceMatches = scriptContent.match(/"salePrice":\s*(\d+(?:\.\d+)?)/i) ||
                                       scriptContent.match(/"price":\s*(\d+(?:\.\d+)?)/i) ||
                                       scriptContent.match(/"discountedPrice":\s*(\d+(?:\.\d+)?)/i) ||
                                       scriptContent.match(/"currentPrice":\s*(\d+(?:\.\d+)?)/i);
                  if (priceMatches && priceMatches[1]) {
                    const price = parsePrice(priceMatches[1]);
                    if (price > 0 && price < 1000000) {
                      priceFromLink = price;
                      console.log(`✅ Trendyol fiyat bulundu (Script JSON): ${priceFromLink}`);
                      break;
                    }
                  }
                }

                // Script'te bulunamadıysa HTML selector'larını dene
                if (!priceFromLink) {
                  const trendyolSelectors = [
                    '.prc-dsc', // İndirimli fiyat (öncelikli)
                    '.pr-new-br', // Yeni fiyat
                    '.prc-box-dscntd', // İndirimli fiyat kutusu
                    '[data-price]', // Data attribute
                    '.product-price-container .prc-dsc', // Container içindeki fiyat
                    '.pr-bx-w .prc-dsc', // Fiyat kutusu içindeki indirimli fiyat
                  ];

                  for (const selector of trendyolSelectors) {
                    const priceText = $(selector).first().text() ||
                                      $(selector).first().attr('data-price') ||
                                      $(selector).first().attr('data-sale-price');
                    if (priceText) {
                      const price = parsePrice(priceText);
                      if (price > 0 && price < 1000000) {
                        priceFromLink = price;
                        console.log(`✅ Trendyol fiyat bulundu (${selector}): ${priceFromLink}`);
                        break;
                      }
                    }
                  }
                }
              }

              // Hepsiburada özel selector'ları
              if (!priceFromLink && hostname.includes('hepsiburada')) {
                console.log('🔍 Hepsiburada fiyat selector\'ları deneniyor...');
                const hbSelectors = [
                  '.price-value', // Fiyat değeri
                  '[data-bind*="price"]', // Data bind
                  '.product-price .price-value', // Container içindeki fiyat
                ];

                for (const selector of hbSelectors) {
                  const priceText = $(selector).first().text() ||
                                    $(selector).first().attr('data-price');
                  if (priceText) {
                    const price = parsePrice(priceText);
                    if (price > 0 && price < 1000000) {
                      priceFromLink = price;
                      console.log(`✅ Hepsiburada fiyat bulundu (${selector}): ${priceFromLink}`);
                      break;
                    }
                  }
                }
              }

              // N11 özel selector'ları
              if (!priceFromLink && hostname.includes('n11')) {
                console.log('🔍 N11 fiyat selector\'ları deneniyor...');
                const n11Selectors = [
                  '.newPrice', // Yeni fiyat
                  '.priceContainer .newPrice', // Container içindeki fiyat
                ];

                for (const selector of n11Selectors) {
                  const priceText = $(selector).first().text();
                  if (priceText) {
                    const price = parsePrice(priceText);
                    if (price > 0 && price < 1000000) {
                      priceFromLink = price;
                      console.log(`✅ N11 fiyat bulundu (${selector}): ${priceFromLink}`);
                      break;
                    }
                  }
                }
              }
            }

            // Öncelik 6: Genel Price class'ları (Türk e-ticaret siteleri)
            if (!priceFromLink) {
              const priceSelectors = [
                '.price, .fiyat, .product-price, .current-price, .sale-price',
                '[class*="price"]:not([class*="old"]):not([class*="discount"]):not([class*="original"])',
                '[class*="fiyat"]:not([class*="eski"]):not([class*="orijinal"])',
              ];

              for (const selector of priceSelectors) {
                const priceText = $(selector).first().text();
                if (priceText) {
                  const price = parsePrice(priceText);
                  if (price > 0 && price < 1000000) {
                    priceFromLink = price;
                    console.log('✅ Fiyat bulundu (Genel Class): ' + priceFromLink);
                    break;
                  }
                }
              }
            }

            // Öncelik 7: Regex ile HTML'de ara (son çare)
            if (!priceFromLink) {
              const priceRegex = /(?:₺|TL|lira)[\s:]*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)/gi;
              const matches = linkData.html.match(priceRegex);
              if (matches && matches.length > 0) {
                const price = parsePrice(matches[0]);
                if (price > 0 && price < 1000000) {
                  priceFromLink = price;
                  console.log('✅ Fiyat bulundu (Regex): ' + priceFromLink);
                }
              }
            }
          }
        } catch (linkError) {
          console.error('❌ Linkten fiyat çekme hatası:', linkError.message);
        }
      }

      // Fiyatı güncelle (linkten bulunduysa öncelikli, yoksa mesajdan parse edilen)
      if (priceFromLink !== null && priceFromLink > 0) {
        parsedDeal.price = priceFromLink;
        console.log(`💰 Fiyat linkten güncellendi: ${parsedDeal.price} TL`);
      } else if (parsedDeal.price === 0) {
        console.log('⚠️ Linkten fiyat bulunamadı, mesajdan parse edilen fiyat kullanılıyor (varsa)');
      }

      // Firestore'a kaydet
      const dealData = {
        title: parsedDeal.title,
        price: parsedDeal.price || 0,
        store: parsedDeal.store || 'Bilinmeyen Mağaza',
        category: parsedDeal.category,
        link: parsedDeal.link,
        imageUrl: imageUrl || '', // Blob URL ise boş string olarak kaydet
        description: parsedDeal.description || messageText, // Description ekle
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        postedBy: `telegram_channel_${channelUsername.startsWith('@') ?
            channelUsername.replace('@', '') : channelUsername}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isEditorPick: false,
        isApproved: false,
        isExpired: false,
        hotVoters: [],
        coldVoters: [],
        source: 'telegram',
        telegramMessageId: messageId,
        telegramChatId: channel.id ? channel.id.toString() : '',
        telegramChatType: channel.broadcast ? 'channel' : 'group',
        telegramChatTitle: channel.title || channelUsername,
        telegramChatUsername: channelUsername.startsWith('@') ?
            channelUsername.replace('@', '') : channelUsername,
        rawMessage: messageText,
      };

      const docRef = await db.collection('deals').add(dealData);
      console.log(`Deal Firestore'a kaydedildi: ${docRef.id}`);
      newDeals.push(docRef.id);
    }

    await client.disconnect();
    return newDeals;
  } catch (error) {
    console.error('Kanal mesajları çekilirken hata:', error);
    await client.disconnect();
    throw error;
  }
}

module.exports = {fetchChannelMessages, parseTelegramMessage};

