const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cheerio = require('cheerio');
const crypto = require('crypto');
const { logErrorToFirestore } = require('./error_logger');

// FS-KUP-02: Deterministik Doküman Kimliği Üreticisi
// Rastgele ID yerine mağaza adı ve koddan benzersiz, stabil ID üretir.
// Böylece her cron çalışmasında oylar sıfırlanmaz, kullanıcı kilitleri bozulmaz ve yetim votes alt dokümanları oluşmaz.
function generateCouponDocId(coupon) {
  const store = (coupon.magazaAdi || 'magaza')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]/g, '_');
  const code = (coupon.kuponKodu || '')
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9_-]/g, '_');
  if (code.length > 0) {
    return `web_${store}_${code}`;
  }
  const hash = crypto.createHash('md5').update((coupon.baslik || '').trim().toLowerCase()).digest('hex').substring(0, 10);
  return `web_${store}_${hash}`;
}

// ─── Ortak Sabitler ──────────────────────────────────────────────────────────

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

// Uygulamadaki 20+ desteklenen mağaza
const SUPPORTED_STORES = [
  'Trendyol', 'Hepsiburada', 'Amazon', 'N11', 'Pazarama',
  'Teknosa', 'MediaMarkt', 'Mavi', 'DeFacto', 'Zara',
  'Mango', 'Beymen', 'PttAVM', 'İncehesap', 'Idefix',
  'Havit', 'Migros', 'Getir', 'Boyner', 'CarrefourSA',
  'Watsons', 'Gratis'
];

// Slug → Uygulama mağaza adı eşleştirmesi (kuponla.com ve kuponburada.com için)
const SLUG_TO_STORE = {
  'trendyol': 'Trendyol',
  'hepsiburada': 'Hepsiburada',
  'amazon': 'Amazon',
  'amazon-com-tr': 'Amazon',
  'amazoncomtr': 'Amazon',
  'n11': 'N11',
  'pazarama': 'Pazarama',
  'teknosa': 'Teknosa',
  'mediamarkt': 'MediaMarkt',
  'media-markt': 'MediaMarkt',
  'mavi': 'Mavi',
  'defacto': 'DeFacto',
  'zara': 'Zara',
  'mango': 'Mango',
  'beymen': 'Beymen',
  'pttavm': 'PttAVM',
  'ptt-avm': 'PttAVM',
  'incehesap': 'İncehesap',
  'idefix': 'Idefix',
  'havit': 'Havit',
  'migros': 'Migros',
  'getir': 'Getir',
  'boyner': 'Boyner',
  'carrefoursa': 'CarrefourSA',
  'carrefour': 'CarrefourSA',
  'watsons': 'Watsons',
  'gratis': 'Gratis',
};

// DonanimHaber mağaza → URL haritası
const DH_STORES_MAP = {
  'Trendyol': 'https://indirimkodu.donanimhaber.com/trendyol/',
  'Hepsiburada': 'https://indirimkodu.donanimhaber.com/hepsiburada/',
  'Amazon': 'https://indirimkodu.donanimhaber.com/amazon/',
  'N11': 'https://indirimkodu.donanimhaber.com/n11/',
  'Pazarama': 'https://indirimkodu.donanimhaber.com/pazarama/',
  'Idefix': 'https://indirimkodu.donanimhaber.com/idefix/',
  'Teknosa': 'https://indirimkodu.donanimhaber.com/teknosa/',
  'Mavi': 'https://indirimkodu.donanimhaber.com/mavi/',
  'DeFacto': 'https://indirimkodu.donanimhaber.com/defacto/',
  'Zara': 'https://indirimkodu.donanimhaber.com/zara/',
  'Mango': 'https://indirimkodu.donanimhaber.com/mango/',
  'Beymen': 'https://indirimkodu.donanimhaber.com/beymen/',
  'PttAVM': 'https://indirimkodu.donanimhaber.com/pttavm/',
  'İncehesap': 'https://indirimkodu.donanimhaber.com/incehesap/',
  'Migros': 'https://indirimkodu.donanimhaber.com/migros/',
  'Getir': 'https://indirimkodu.donanimhaber.com/getir/',
  'CarrefourSA': 'https://indirimkodu.donanimhaber.com/carrefoursa/',
  'Watsons': 'https://indirimkodu.donanimhaber.com/watsons/',
  'Gratis': 'https://indirimkodu.donanimhaber.com/gratis/'
};

// Kuponburada mağaza → URL haritası (Hedefli Mağaza Sayfaları - 150+ Doğrulanmış Kupon)
const KB_STORES_MAP = {
  'Trendyol': 'https://www.kuponburada.com/trendyol-indirim-kodu/',
  'Hepsiburada': 'https://www.kuponburada.com/hepsiburada-indirim-kodu/',
  'Amazon': 'https://www.kuponburada.com/amazon-indirim-kodu/',
  'N11': 'https://www.kuponburada.com/n11-indirim-kodu/',
  'Teknosa': 'https://www.kuponburada.com/teknosa-indirim-kodu/',
  'MediaMarkt': 'https://www.kuponburada.com/mediamarkt-indirim-kodu/',
  'Mavi': 'https://www.kuponburada.com/mavi-indirim-kodu/',
  'DeFacto': 'https://www.kuponburada.com/defacto-indirim-kodu/',
  'Mango': 'https://www.kuponburada.com/mango-indirim-kodu/',
  'Beymen': 'https://www.kuponburada.com/beymen-indirim-kodu/',
  'PttAVM': 'https://www.kuponburada.com/pttavm-indirim-kodu/',
  'Idefix': 'https://www.kuponburada.com/idefix-indirim-kodu/',
  'Migros': 'https://www.kuponburada.com/migros-indirim-kodu/',
  'Getir': 'https://www.kuponburada.com/getir-indirim-kodu/',
  'Boyner': 'https://www.kuponburada.com/boyner-indirim-kodu/',
  'CarrefourSA': 'https://www.kuponburada.com/carrefoursa-indirim-kodu/',
  'Watsons': 'https://www.kuponburada.com/watsons-indirim-kodu/',
  'Gratis': 'https://www.kuponburada.com/gratis-indirim-kodu/'
};

// ─── Yardımcı Fonksiyonlar ──────────────────────────────────────────────────

function resolveStoreName(slugOrName) {
  if (!slugOrName) return null;
  const normalized = slugOrName
    .toLowerCase()
    .trim()
    .replace(/-indirim-kodu/g, '')
    .replace(/\.com(\.tr)?/g, '');
  if (SLUG_TO_STORE[normalized]) return SLUG_TO_STORE[normalized];
  for (const store of SUPPORTED_STORES) {
    if (normalized === store.toLowerCase()) return store;
  }
  return null;
}

function resolveStoreFromKuponlaName(storeNameText) {
  if (!storeNameText) return null;
  const cleaned = storeNameText
    .replace(/\s*kuponları?\s*/gi, '')
    .replace(/\.com\.tr/gi, '')
    .replace(/\.com/gi, '')
    .trim();
  for (const store of SUPPORTED_STORES) {
    if (cleaned.toLowerCase() === store.toLowerCase() || cleaned.toLowerCase().startsWith(store.toLowerCase())) return store;
  }
  return resolveStoreName(cleaned) || null;
}

async function safeFetch(url, headers = {}, timeoutMs = 10000) {
  try {
    const response = await fetch(url, {
      headers: { 'User-Agent': USER_AGENT, ...headers },
      signal: AbortSignal.timeout(timeoutMs)
    });
    if (!response.ok) return null;
    return await response.text();
  } catch (err) {
    functions.logger.warn(`⚠️ Fetch failed for ${url}: ${err.message}`);
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KAYNAK 1: DonanimHaber (Ana Kaynak)
// ═══════════════════════════════════════════════════════════════════════════════

async function scrapeDonanimHaber() {
  functions.logger.info('📡 [DonanimHaber] Scraping started...');
  const coupons = [];
  const successfulStores = new Set();

  for (const [storeName, storeUrl] of Object.entries(DH_STORES_MAP)) {
    try {
      functions.logger.info(`🔍 [DonanimHaber] Scraping coupons for ${storeName}...`);
      
      const html = await safeFetch(storeUrl, {}, 10000);
      if (!html) {
        functions.logger.warn(`⚠️ [DonanimHaber] Failed to fetch page for ${storeName}.`);
        continue;
      }
      successfulStores.add(storeName);
      const $ = cheerio.load(html);

      const expiredHeading = $('h2').filter((i, el) => $(el).text().includes('Geçmiş Kuponlar'));
      if (expiredHeading.length > 0) {
        expiredHeading.nextAll().remove();
        expiredHeading.remove();
      }

      const storeCoupons = [];
      const seenCouponIds = new Set();

      $('a[data-single*="/kupon/"]').each((i, el) => {
        const dataSingle = $(el).attr('data-single');
        const dataCouponId = $(el).attr('data-coupon-id');
        if (dataSingle && dataCouponId && !seenCouponIds.has(dataCouponId)) {
          seenCouponIds.add(dataCouponId);
          storeCoupons.push({
            detailUrl: dataSingle,
            couponId: dataCouponId
          });
        }
      });

      functions.logger.info(`[DonanimHaber] Found ${storeCoupons.length} potential coupons for ${storeName}.`);

      for (const coupon of storeCoupons) {
        try {
          const finalUrl = `${coupon.detailUrl}?_c=${coupon.couponId}`;
          const detailHtml = await safeFetch(finalUrl, {}, 5000);

          if (detailHtml) {
            const $detail = cheerio.load(detailHtml);
            const title = $detail('meta[property="og:title"]').attr('content') || '';
            const description = $detail('meta[property="og:description"]').attr('content') || '';
            const couponCode = $detail('input#coupon_copy').attr('value') || '';

            if (couponCode.trim()) {
              coupons.push({
                magazaAdi: storeName,
                baslik: title.trim() || `${storeName} İndirim Kuponu`,
                aciklama: description.trim(),
                kuponKodu: couponCode.trim(),
                paylasanKullaniciId: 'admin',
                kaynakTipi: 'web',
                kaynakSite: 'donanimhaber',
                sicakOySayisi: 0,
                sogukOySayisi: 0,
                durum: 'aktif'
              });
            }
          }
          await new Promise(resolve => setTimeout(resolve, 100));
        } catch (detailErr) {
          functions.logger.error(`❌ [DonanimHaber] Error scraping coupon detail ${coupon.detailUrl}:`, detailErr.message);
        }
      }

    } catch (storeErr) {
      functions.logger.error(`❌ [DonanimHaber] Error scraping store ${storeName}:`, storeErr.message);
    }
  }

  functions.logger.info(`📡 [DonanimHaber] Finished. Scraped ${coupons.length} coupons across ${successfulStores.size} stores.`);
  return { coupons, successfulStores: Array.from(successfulStores) };
}

// ═══════════════════════════════════════════════════════════════════════════════
// KAYNAK 2: Kuponla.com (Yardımcı Kaynak)
// ═══════════════════════════════════════════════════════════════════════════════

async function scrapeKuponlaPage(pageUrl) {
  const coupons = [];
  const html = await safeFetch(pageUrl, {}, 15000);
  if (!html) {
    functions.logger.warn(`⚠️ [Kuponla] Failed to fetch page: ${pageUrl}`);
    return coupons;
  }

  const $ = cheerio.load(html);

  $('div.coupon-item').each((i, el) => {
    try {
      const $item = $(el);
      const codeButton = $item.find('a.coupon-code[data-code]');
      if (codeButton.length === 0) return;

      const couponCode = (codeButton.attr('data-code') || '').trim();
      if (!couponCode) return;

      const storeNameText = $item.find('div.store-name > a').text().trim();
      const storeName = resolveStoreFromKuponlaName(storeNameText);
      if (!storeName) return;

      const titleLink = $item.find('h3.coupon-title > a');
      const title = (titleLink.attr('title') || titleLink.text() || '').trim();

      let description = '';
      const desFullEl = $item.find('div.coupon-des-full > p').first();
      if (desFullEl.length > 0) {
        description = desFullEl.text().trim();
      } else {
        const desEllip = $item.find('div.coupon-des-ellip').clone();
        desEllip.find('span.c-actions-span').remove();
        description = desEllip.text().trim();
      }

      coupons.push({
        magazaAdi: storeName,
        baslik: title || `${storeName} İndirim Kuponu`,
        aciklama: description,
        kuponKodu: couponCode,
        paylasanKullaniciId: 'admin',
        kaynakTipi: 'web',
        kaynakSite: 'kuponla',
        sicakOySayisi: 0,
        sogukOySayisi: 0,
        durum: 'aktif'
      });
    } catch (itemErr) {
      functions.logger.warn(`⚠️ [Kuponla] Error parsing coupon item:`, itemErr.message);
    }
  });

  return coupons;
}

async function scrapeKuponla() {
  functions.logger.info('📡 [Kuponla] Scraping started...');
  const allCoupons = [];

  try {
    const page1Coupons = await scrapeKuponlaPage('https://kuponla.com/son-eklenen-kuponlar/');
    allCoupons.push(...page1Coupons);
    functions.logger.info(`[Kuponla] Page 1: Found ${page1Coupons.length} code coupons.`);

    await new Promise(resolve => setTimeout(resolve, 200));
    const page2Coupons = await scrapeKuponlaPage('https://kuponla.com/son-eklenen-kuponlar/page/2/');
    allCoupons.push(...page2Coupons);
    functions.logger.info(`[Kuponla] Page 2: Found ${page2Coupons.length} code coupons.`);

  } catch (err) {
    functions.logger.error(`❌ [Kuponla] Fatal error:`, err.message);
  }

  functions.logger.info(`📡 [Kuponla] Finished. Total scraped: ${allCoupons.length} coupons.`);
  return allCoupons;
}

// ═══════════════════════════════════════════════════════════════════════════════
// KAYNAK 3: Kuponburada.com (Hedefli Mağaza Sayfaları + Keşfet Keşif Katmanı)
// ═══════════════════════════════════════════════════════════════════════════════

async function scrapeKuponburada() {
  functions.logger.info('📡 [Kuponburada] Store-targeted scraping started...');
  const coupons = [];
  const seenCodes = new Set();
  const successfulStores = new Set();

  // 1. ADIM: 15 Büyük Mağaza Sayfasını Hedefli Kazı (130+ Doğrulanmış Kupon)
  for (const [storeName, storeUrl] of Object.entries(KB_STORES_MAP)) {
    try {
      const html = await safeFetch(storeUrl, {}, 10000);
      if (!html) continue;
      successfulStores.add(storeName);

      const $ = cheerio.load(html);
      let storeCount = 0;

      $('li[data-coupon-type="code"]').each((i, el) => {
        try {
          const $item = $(el);
          const expired = $item.find('article').attr('data-coupon-expired');
          if (expired === '1') return;

          const couponButton = $item.find('a.coupon-button');
          const ariaLabel = couponButton.attr('aria-label') || couponButton.text() || '';
          const codeMatch = ariaLabel.match(/Kod:\s*([^,\n\r]+)/i);
          const couponCode = codeMatch ? codeMatch[1].trim() : '';
          if (!couponCode) return;

          const title = $item.find('h3').first().text().trim();
          let description = $item.find('p').first().text().trim();
          if (!description) {
            description = $item.find('div.sr-only, .text-body, [class*="text-body"]').first().text().trim();
          }

          const codeKey = `${storeName.toUpperCase()}_${couponCode.toUpperCase()}`;
          if (!seenCodes.has(codeKey)) {
            seenCodes.add(codeKey);
            coupons.push({
              magazaAdi: storeName,
              baslik: title || `${storeName} İndirim Kodu`,
              aciklama: description,
              kuponKodu: couponCode,
              paylasanKullaniciId: 'admin',
              kaynakTipi: 'web',
              kaynakSite: 'kuponburada',
              sicakOySayisi: 0,
              sogukOySayisi: 0,
              durum: 'aktif'
            });
            storeCount++;
          }
        } catch (itemErr) {
          functions.logger.warn(`⚠️ [Kuponburada] ${storeName} item parse error:`, itemErr.message);
        }
      });
      functions.logger.debug(`[Kuponburada] ${storeName}: Extracted ${storeCount} coupons.`);
      // Mağazalar arası nazik jitter (Rate limit koruması)
      await new Promise(r => setTimeout(r, 100 + Math.random() * 100));
    } catch (storeErr) {
      functions.logger.warn(`⚠️ [Kuponburada] Failed for ${storeName}:`, storeErr.message);
    }
  }

  // 2. ADIM: /kesfet/ Akışından Yeni Yayınlanan Desteklenen Kuponları Yakala (Tamamlayıcı Katman)
  try {
    const kesfetHtml = await safeFetch('https://www.kuponburada.com/kesfet/', {}, 10000);
    if (kesfetHtml) {
      const $ = cheerio.load(kesfetHtml);
      let kesfetAdded = 0;

      $('li[data-coupon-type="code"]').each((i, el) => {
        try {
          const $item = $(el);
          const expired = $item.find('article').attr('data-coupon-expired');
          if (expired === '1') return;

          const couponButton = $item.find('a.coupon-button');
          const ariaLabel = couponButton.attr('aria-label') || couponButton.text() || '';
          const codeMatch = ariaLabel.match(/Kod:\s*([^,\n\r]+)/i);
          const couponCode = codeMatch ? codeMatch[1].trim() : '';
          if (!couponCode) return;

          const brandSlug = couponButton.attr('data-brand-slug') || $item.find('article').attr('data-brand-slug') || '';
          const storeName = resolveStoreName(brandSlug);
          if (!storeName) return;

          const title = $item.find('h3').first().text().trim();
          let description = $item.find('p').first().text().trim();
          if (!description) {
            description = $item.find('div.sr-only, .text-body, [class*="text-body"]').first().text().trim();
          }

          const codeKey = `${storeName.toUpperCase()}_${couponCode.toUpperCase()}`;
          if (!seenCodes.has(codeKey)) {
            seenCodes.add(codeKey);
            coupons.push({
              magazaAdi: storeName,
              baslik: title || `${storeName} İndirim Kodu`,
              aciklama: description,
              kuponKodu: couponCode,
              paylasanKullaniciId: 'admin',
              kaynakTipi: 'web',
              kaynakSite: 'kuponburada',
              sicakOySayisi: 0,
              sogukOySayisi: 0,
              durum: 'aktif'
            });
            kesfetAdded++;
          }
        } catch (e) {}
      });
      if (kesfetAdded > 0) {
        functions.logger.info(`[Kuponburada] /kesfet/ stream added ${kesfetAdded} extra coupons.`);
      }
    }
  } catch (kesfetErr) {
    functions.logger.debug('[Kuponburada] /kesfet/ stream optional check skipped:', kesfetErr.message);
  }

  functions.logger.info(`📡 [Kuponburada] Finished. Total scraped: ${coupons.length} coupons across ${successfulStores.size} stores.`);
  return { coupons, successfulStores: Array.from(successfulStores) };
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANA FONKSİYON: Tüm Kaynakları Birleştir, Mükerrerleri Filtrele, Firestore'a Yaz
// ═══════════════════════════════════════════════════════════════════════════════

async function scrapeAndSaveCoupons() {
  functions.logger.info('🚀 Multi-source coupon scraping started...');
  
  const dhResult = await scrapeDonanimHaber();
  const dhCoupons = dhResult.coupons || [];
  const successfulDhStores = new Set(dhResult.successfulStores || []);

  const seenCodes = new Set();
  const allScrapedCoupons = [];

  for (const coupon of dhCoupons) {
    const codeKey = `${(coupon.magazaAdi || '').toUpperCase()}_${coupon.kuponKodu.toUpperCase()}`;
    if (!seenCodes.has(codeKey)) {
      seenCodes.add(codeKey);
      allScrapedCoupons.push(coupon);
    }
  }
  functions.logger.info(`After DonanimHaber: ${allScrapedCoupons.length} unique coupons across ${successfulDhStores.size} stores.`);

  let kuponlaSucceeded = false;
  try {
    const kuponlaCoupons = await scrapeKuponla();
    kuponlaSucceeded = true;
    let kuponlaAdded = 0;
    for (const coupon of kuponlaCoupons) {
      const codeKey = `${(coupon.magazaAdi || '').toUpperCase()}_${coupon.kuponKodu.toUpperCase()}`;
      if (!seenCodes.has(codeKey)) {
        seenCodes.add(codeKey);
        allScrapedCoupons.push(coupon);
        kuponlaAdded++;
      }
    }
    functions.logger.info(`[Kuponla] Added ${kuponlaAdded} new unique coupons.`);
  } catch (err) {
    functions.logger.error(`❌ [Kuponla] Entire source failed, skipping:`, err.message);
    await logErrorToFirestore('catalogs_coupons', 'Kuponla Scrape Failed', err.message, err.stack, 'warning', {
      category: 'catalogs_coupons',
      subCategory: 'kuponla'
    });
  }

  let kuponburadaSucceeded = false;
  const successfulKbStores = new Set();
  try {
    const kbResult = await scrapeKuponburada();
    const kuponburadaCoupons = Array.isArray(kbResult) ? kbResult : (kbResult.coupons || []);
    if (kbResult.successfulStores) {
      kbResult.successfulStores.forEach(s => successfulKbStores.add(s));
    }
    kuponburadaSucceeded = true;
    let kuponburadaAdded = 0;
    for (const coupon of kuponburadaCoupons) {
      const codeKey = `${(coupon.magazaAdi || '').toUpperCase()}_${coupon.kuponKodu.toUpperCase()}`;
      if (!seenCodes.has(codeKey)) {
        seenCodes.add(codeKey);
        allScrapedCoupons.push(coupon);
        kuponburadaAdded++;
      }
    }
    functions.logger.info(`[Kuponburada] Added ${kuponburadaAdded} new unique coupons across ${successfulKbStores.size} stores.`);
  } catch (err) {
    functions.logger.error(`❌ [Kuponburada] Entire source failed, skipping:`, err.message);
    await logErrorToFirestore('catalogs_coupons', 'Kuponburada Scrape Failed', err.message, err.stack, 'warning', {
      category: 'catalogs_coupons',
      subCategory: 'kuponburada'
    });
  }

  functions.logger.info(`✨ All sources scraped. Total unique coupons: ${allScrapedCoupons.length}`);

  if (allScrapedCoupons.length === 0) {
    functions.logger.warn('⚠️ No coupons scraped from any source. Keeping existing coupons.');
    await logErrorToFirestore('catalogs_coupons', 'Coupon Scrape Zero Result', 'Tüm kupon kaynaklarından (DH, Kuponla, Kuponburada) 0 kupon çekildi. Kaynakların DOM yapısı değişmiş olabilir.', null, 'error', {
      category: 'catalogs_coupons'
    });
    return { success: false, count: 0, message: 'Hiç kupon çekilemedi. Mevcut kuponlar korunuyor.' };
  }

  const db = admin.firestore();

  // 1. ADIM: Mevcut web kuponlarını çekip oy sayılarını, mağazalarını, kaynaklarını ve tarihlerini hafızaya al
  // FS-KUP-02: Böylece deterministik ID ile güncellenen kuponların oyları ve orijinal tarihleri korunur!
  functions.logger.info('🔍 Fetching existing web coupons to preserve votes and timestamps...');
  const existingDocsSnapshot = await db.collection('kuponlar').where('kaynakTipi', '==', 'web').get();
  const existingDocsMap = new Map();
  for (const doc of existingDocsSnapshot.docs) {
    const data = doc.data();
    existingDocsMap.set(doc.id, {
      ref: doc.ref,
      magazaAdi: data.magazaAdi || '',
      kaynakSite: data.kaynakSite || '',
      sicakOySayisi: data.sicakOySayisi || 0,
      sogukOySayisi: data.sogukOySayisi || 0,
      olusturulmaTarihi: data.olusturulmaTarihi,
      durum: data.durum || 'aktif',
      sonlanmaTarihi: data.sonlanmaTarihi || null,
      sonlanmaNedeni: data.sonlanmaNedeni || null
    });
  }

  // 2. ADIM: Deterministik ID ve Upsert mimarisiyle kuponları hazırla
  const baseNow = Date.now();
  const couponsToUpsert = [];
  const newDocIdSet = new Set();

  for (let i = 0; i < allScrapedCoupons.length; i++) {
    const couponData = allScrapedCoupons[i];
    const docId = generateCouponDocId(couponData);

    // Aynı kaynaklar arası tekil ID kuralı
    if (newDocIdSet.has(docId)) continue;
    newDocIdSet.add(docId);

    const existing = existingDocsMap.get(docId);
    if (existing) {
      // Mevcut kuponun oylarını ve orijinal oluşturulma tarihini koru
      couponData.sicakOySayisi = existing.sicakOySayisi;
      couponData.sogukOySayisi = existing.sogukOySayisi;

      // P0-KUP-01: Zombi Kupon Dirilme Koruması:
      // Kullanıcı topluluğu veya admin tarafından 'gecersiz' kılınmış kuponları tekrar 'aktif' yapma!
      if (existing.durum === 'gecersiz') {
        couponData.durum = 'gecersiz';
        if (existing.sonlanmaTarihi) {
          couponData.sonlanmaTarihi = existing.sonlanmaTarihi;
        }
        if (existing.sonlanmaNedeni) {
          couponData.sonlanmaNedeni = existing.sonlanmaNedeni;
        }
      }

      if (existing.olusturulmaTarihi) {
        couponData.olusturulmaTarihi = existing.olusturulmaTarihi;
      } else {
        couponData.olusturulmaTarihi = admin.firestore.Timestamp.fromDate(new Date(baseNow - (i * 1000)));
      }
    } else {
      // Yeni eklenen kupon
      couponData.sicakOySayisi = 0;
      couponData.sogukOySayisi = 0;
      couponData.olusturulmaTarihi = admin.firestore.Timestamp.fromDate(new Date(baseNow - (i * 1000)));
    }

    couponsToUpsert.push({ docId, data: couponData });
  }

  // 3. ADIM: Chunks halinde batch.set(..., { merge: true }) ile yaz
  functions.logger.info(`📝 Upserting ${couponsToUpsert.length} deterministic coupons to Firestore...`);
  const writeChunks = [];
  for (let i = 0; i < couponsToUpsert.length; i += 400) {
    writeChunks.push(couponsToUpsert.slice(i, i + 400));
  }

  for (const chunk of writeChunks) {
    const batch = db.batch();
    chunk.forEach(({ docId, data }) => {
      const docRef = db.collection('kuponlar').doc(docId);
      batch.set(docRef, data, { merge: true });
    });
    await batch.commit();
  }
  functions.logger.info(`Successfully upserted ${couponsToUpsert.length} coupons.`);

  // 4. ADIM: Siteden kalkan eski kuponları temizle veya geçersiz işaretle (Kapsamlı Uzlaşma)
  // FS-KUP-02: Kullanıcı oyu olan kuponlar silinmez, 'gecersiz' yapılarak oyları ve votes alt koleksiyonu korunur.
  // Sıfır oyu olanlar ise veritabanını temiz tutmak için silinir.
  functions.logger.info('🧹 Cleaning up stale web-scraped coupons from Firestore (Scoped Reconciliation)...');
  const staleDocs = [];
  for (const [id, info] of existingDocsMap.entries()) {
    if (newDocIdSet.has(id)) continue;

    // Kapsamlı Uzlaşma (Scoped Reconciliation):
    // İlgili kaynak veya mağaza bu kazıma turunda taranamadıysa kuponu silme/geçersizleştirme!
    let shouldEvaluateStale = false;
    if (info.kaynakSite === 'donanimhaber') {
      shouldEvaluateStale = successfulDhStores.has(info.magazaAdi);
    } else if (info.kaynakSite === 'kuponla') {
      shouldEvaluateStale = kuponlaSucceeded;
    } else if (info.kaynakSite === 'kuponburada') {
      shouldEvaluateStale = successfulKbStores.size > 0 ? successfulKbStores.has(info.magazaAdi) : kuponburadaSucceeded;
    } else {
      // Bilinmeyen / eski kayıtlar: en azından mağaza DH'de başarıyla tarandıysa
      shouldEvaluateStale = successfulDhStores.has(info.magazaAdi);
    }

    if (shouldEvaluateStale) {
      staleDocs.push({ id, ...info });
    } else {
      functions.logger.info(`🛡️ [Kupon Scraper] Preserving coupon ${id} (${info.magazaAdi} / ${info.kaynakSite}) - source was not crawled.`);
    }
  }

  const cleanupChunks = [];
  for (let i = 0; i < staleDocs.length; i += 400) {
    cleanupChunks.push(staleDocs.slice(i, i + 400));
  }

  for (const chunk of cleanupChunks) {
    const batch = db.batch();
    chunk.forEach((item) => {
      if (item.sicakOySayisi > 0 || item.sogukOySayisi > 0) {
        // Kullanıcı oyu varsa dokümanı silme; sadece henüz aktifse durumunu geçersiz yap (mükerrer yazma engeli)
        if (item.durum !== 'gecersiz') {
          batch.update(item.ref, {
            durum: 'gecersiz',
            sonlanmaNedeni: 'scraper_stale',
            sonlanmaTarihi: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      } else {
        // Hiç oyu olmayan çöp dokümanı güvenle sil
        batch.delete(item.ref);
      }
    });
    await batch.commit();
  }
  functions.logger.info(`Processed ${staleDocs.length} stale coupons (preserved voted, removed unvoted).`);

  const bySource = {};
  for (const c of allScrapedCoupons) {
    bySource[c.kaynakSite] = (bySource[c.kaynakSite] || 0) + 1;
  }
  functions.logger.info(`📊 Source breakdown: ${JSON.stringify(bySource)}`);

  return { success: true, count: allScrapedCoupons.length, breakdown: bySource };
}

module.exports = {
  scrapeAndSaveCoupons
};
