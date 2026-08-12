const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cheerio = require('cheerio');

// ─── Ortak Sabitler ──────────────────────────────────────────────────────────

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

// Uygulamadaki 20 desteklenen mağaza
const SUPPORTED_STORES = [
  'Trendyol', 'Hepsiburada', 'Amazon', 'N11', 'Pazarama',
  'Teknosa', 'MediaMarkt', 'Mavi', 'DeFacto', 'Zara',
  'Mango', 'Beymen', 'PttAVM', 'İncehesap', 'Idefix',
  'Havit', 'Migros', 'Getir', 'Boyner'
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
  'Getir': 'https://indirimkodu.donanimhaber.com/getir/'
};

// ─── Yardımcı Fonksiyonlar ──────────────────────────────────────────────────

function resolveStoreName(slugOrName) {
  if (!slugOrName) return null;
  const normalized = slugOrName.toLowerCase().trim();
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
    if (cleaned.toLowerCase() === store.toLowerCase()) return store;
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

  for (const [storeName, storeUrl] of Object.entries(DH_STORES_MAP)) {
    try {
      functions.logger.info(`🔍 [DonanimHaber] Scraping coupons for ${storeName}...`);
      
      const html = await safeFetch(storeUrl, {}, 10000);
      if (!html) {
        functions.logger.warn(`⚠️ [DonanimHaber] Failed to fetch page for ${storeName}.`);
        continue;
      }
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

  functions.logger.info(`📡 [DonanimHaber] Finished. Scraped ${coupons.length} coupons.`);
  return coupons;
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
// KAYNAK 3: Kuponburada.com (LD+JSON Page 1 + AJAX Page 2)
// ═══════════════════════════════════════════════════════════════════════════════

async function scrapeKuponburada() {
  functions.logger.info('📡 [Kuponburada] Scraping started (LD+JSON + AJAX Page 2)...');
  const coupons = [];
  const seenCodes = new Set();

  // ── Sayfa 1: LD+JSON Ayrıştırma ─────────────────────────────────
  try {
    const page1Html = await safeFetch('https://www.kuponburada.com/kesfet/yeni-indirim-kuponlari/', {}, 15000);
    if (page1Html) {
      const $ = cheerio.load(page1Html);

      $('script[type="application/ld+json"]').each((i, el) => {
        try {
          const jsonText = $(el).html();
          if (!jsonText) return;
          const parsed = JSON.parse(jsonText);
          const items = parsed['@graph'] || (Array.isArray(parsed) ? parsed : [parsed]);

          for (const item of items) {
            if (item['@type'] === 'Offer') {
              let couponCode = '';
              if (item.identifier && item.identifier.propertyID === 'couponCode') {
                couponCode = (item.identifier.value || '').trim();
              }
              if (!couponCode) continue;

              const rawStoreName = (item.seller && item.seller.name) ? item.seller.name : '';
              const storeName = resolveStoreName(rawStoreName);
              if (!storeName) continue;

              const title = (item.itemOffered && item.itemOffered.name) || item.name || `${storeName} İndirim Kodu`;
              const description = item.disambiguatingDescription || item.description || (item.itemOffered && item.itemOffered.description) || '';

              const codeKey = couponCode.toUpperCase();
              if (!seenCodes.has(codeKey)) {
                seenCodes.add(codeKey);
                coupons.push({
                  magazaAdi: storeName,
                  baslik: title,
                  aciklama: description,
                  kuponKodu: couponCode,
                  paylasanKullaniciId: 'admin',
                  kaynakTipi: 'web',
                  kaynakSite: 'kuponburada',
                  sicakOySayisi: 0,
                  sogukOySayisi: 0,
                  durum: 'aktif'
                });
              }
            }
          }
        } catch (ldErr) {
          functions.logger.warn(`⚠️ [Kuponburada] LD+JSON parse error:`, ldErr.message);
        }
      });
      functions.logger.info(`[Kuponburada] Page 1 (LD+JSON): Found ${coupons.length} unique code coupons.`);
    }
  } catch (p1Err) {
    functions.logger.error(`❌ [Kuponburada] Page 1 error:`, p1Err.message);
  }

  // ── Sayfa 2: AJAX Endpoint İsteyi ──────────────────────────────
  try {
    const page2Raw = await safeFetch(
      'https://www.kuponburada.com/kesfet/yeni-indirim-kuponlari/?page=2',
      {
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json, text/javascript, */*; q=0.01'
      },
      15000
    );

    if (page2Raw) {
      const page2Json = JSON.parse(page2Raw);
      if (page2Json && page2Json.html) {
        const $2 = cheerio.load(page2Json.html);
        let p2Count = 0;

        $2('li[data-coupon-type="code"]').each((i, el) => {
          try {
            const $item = $2(el);
            const expired = $item.find('article').attr('data-coupon-expired');
            if (expired === '1') return;

            const couponButton = $item.find('a.coupon-button');
            const ariaLabel = couponButton.attr('aria-label') || '';
            const codeMatch = ariaLabel.match(/Kod:\s*([^,]+)/);
            const couponCode = codeMatch ? codeMatch[1].trim() : '';
            if (!couponCode) return;

            const brandSlug = couponButton.attr('data-brand-slug') || '';
            const storeName = resolveStoreName(brandSlug);
            if (!storeName) return;

            const title = $item.find('h3').first().text().trim();
            const srOnlyDivs = $item.find('div.sr-only');
            let description = srOnlyDivs.length > 0 ? srOnlyDivs.first().text().trim() : '';
            if (!description) {
              description = $item.find('p.text-gray-600').first().text().trim();
            }

            const codeKey = couponCode.toUpperCase();
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
              p2Count++;
            }
          } catch (itemErr) {
            functions.logger.warn(`⚠️ [Kuponburada] Page 2 item parse error:`, itemErr.message);
          }
        });
        functions.logger.info(`[Kuponburada] Page 2 (AJAX): Added ${p2Count} new unique code coupons.`);
      }
    }
  } catch (p2Err) {
    functions.logger.error(`❌ [Kuponburada] Page 2 AJAX error:`, p2Err.message);
  }

  functions.logger.info(`📡 [Kuponburada] Finished. Total scraped: ${coupons.length} coupons.`);
  return coupons;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANA FONKSİYON: Tüm Kaynakları Birleştir, Mükerrerleri Filtrele, Firestore'a Yaz
// ═══════════════════════════════════════════════════════════════════════════════

async function scrapeAndSaveCoupons() {
  functions.logger.info('🚀 Multi-source coupon scraping started...');
  
  const dhCoupons = await scrapeDonanimHaber();

  const seenCodes = new Set();
  const allScrapedCoupons = [];

  for (const coupon of dhCoupons) {
    const codeKey = coupon.kuponKodu.toUpperCase();
    if (!seenCodes.has(codeKey)) {
      seenCodes.add(codeKey);
      allScrapedCoupons.push(coupon);
    }
  }
  functions.logger.info(`After DonanimHaber: ${allScrapedCoupons.length} unique coupons.`);

  try {
    const kuponlaCoupons = await scrapeKuponla();
    let kuponlaAdded = 0;
    for (const coupon of kuponlaCoupons) {
      const codeKey = coupon.kuponKodu.toUpperCase();
      if (!seenCodes.has(codeKey)) {
        seenCodes.add(codeKey);
        allScrapedCoupons.push(coupon);
        kuponlaAdded++;
      }
    }
    functions.logger.info(`[Kuponla] Added ${kuponlaAdded} new unique coupons.`);
  } catch (err) {
    functions.logger.error(`❌ [Kuponla] Entire source failed, skipping:`, err.message);
  }

  try {
    const kuponburadaCoupons = await scrapeKuponburada();
    let kuponburadaAdded = 0;
    for (const coupon of kuponburadaCoupons) {
      const codeKey = coupon.kuponKodu.toUpperCase();
      if (!seenCodes.has(codeKey)) {
        seenCodes.add(codeKey);
        allScrapedCoupons.push(coupon);
        kuponburadaAdded++;
      }
    }
    functions.logger.info(`[Kuponburada] Added ${kuponburadaAdded} new unique coupons.`);
  } catch (err) {
    functions.logger.error(`❌ [Kuponburada] Entire source failed, skipping:`, err.message);
  }

  functions.logger.info(`✨ All sources scraped. Total unique coupons: ${allScrapedCoupons.length}`);

  if (allScrapedCoupons.length === 0) {
    functions.logger.warn('⚠️ No coupons scraped from any source. Keeping existing coupons.');
    return { success: false, count: 0, message: 'Hiç kupon çekilemedi. Mevcut kuponlar korunuyor.' };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SIRALAMA DÜZELTMESİ: Sitelerdeki Orijinal Sırayı Birebir Korumak
  // 
  // Sitede en üstte duran kupon dizinin en başındadır (index = 0).
  // Uygulama (Flutter) kuponları `olusturulmaTarihi DESC` (en yeni tarih en üstte)
  // şeklinde sıralar.
  // Sitede en üstteki kuponun uygulamada da EN ÜSTTE görünmesi için,
  // index 0'a en yeni (en büyük) tarihi veriyoruz. Sonraki kuponlara 1'er saniye
  // daha eski tarihler veriyoruz.
  // ─────────────────────────────────────────────────────────────────────────────
  const baseNow = Date.now();
  for (let i = 0; i < allScrapedCoupons.length; i++) {
    const customDate = new Date(baseNow - (i * 1000));
    allScrapedCoupons[i].olusturulmaTarihi = admin.firestore.Timestamp.fromDate(customDate);
  }

  const db = admin.firestore();
  
  functions.logger.info('🧹 Deleting existing web-scraped coupons from Firestore...');
  const querySnapshot = await db.collection('kuponlar').where('kaynakTipi', '==', 'web').get();
  const deleteDocs = querySnapshot.docs;
  const deleteChunks = [];
  
  for (let i = 0; i < deleteDocs.length; i += 500) {
    deleteChunks.push(deleteDocs.slice(i, i + 500));
  }

  for (const chunk of deleteChunks) {
    const batch = db.batch();
    chunk.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
  }
  functions.logger.info(`Deleted ${deleteDocs.length} old web-scraped coupons.`);

  functions.logger.info('📝 Writing newly scraped coupons to Firestore...');
  const writeChunks = [];
  
  for (let i = 0; i < allScrapedCoupons.length; i += 500) {
    writeChunks.push(allScrapedCoupons.slice(i, i + 500));
  }

  for (const chunk of writeChunks) {
    const batch = db.batch();
    chunk.forEach((couponData) => {
      const docRef = db.collection('kuponlar').doc();
      batch.set(docRef, couponData);
    });
    await batch.commit();
  }
  functions.logger.info(`Successfully saved ${allScrapedCoupons.length} coupons.`);

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
