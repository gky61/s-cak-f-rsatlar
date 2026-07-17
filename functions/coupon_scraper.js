const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cheerio = require('cheerio');

const STORES_MAP = {
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

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/**
 * Scrapes all coupons from DonanimHaber and updates Firestore.
 */
async function scrapeAndSaveCoupons() {
  functions.logger.info('🚀 Coupon scraping process started using native fetch...');
  const allScrapedCoupons = [];

  for (const [storeName, storeUrl] of Object.entries(STORES_MAP)) {
    try {
      functions.logger.info(`🔍 Scraping coupons for ${storeName} from ${storeUrl}...`);
      
      const response = await fetch(storeUrl, {
        headers: { 'User-Agent': USER_AGENT },
        signal: AbortSignal.timeout(10000)
      });

      if (!response.ok) {
        functions.logger.warn(`⚠️ Failed to fetch page for ${storeName}. Status: ${response.status}`);
        continue;
      }
      const html = await response.text();
      const $ = cheerio.load(html);

      // Filter out expired coupons (under "Geçmiş Kuponlar" heading)
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

      functions.logger.info(`Found ${storeCoupons.length} potential coupons for ${storeName}.`);

      // Fetch details for each coupon sequentially with a small delay
      for (const coupon of storeCoupons) {
        try {
          const finalUrl = `${coupon.detailUrl}?_c=${coupon.couponId}`;
          const detailResponse = await fetch(finalUrl, {
            headers: { 'User-Agent': USER_AGENT },
            signal: AbortSignal.timeout(5000)
          });

          if (detailResponse.ok) {
            const detailHtml = await detailResponse.text();
            const $detail = cheerio.load(detailHtml);
            const title = $detail('meta[property="og:title"]').attr('content') || '';
            const description = $detail('meta[property="og:description"]').attr('content') || '';
            const couponCode = $detail('input#coupon_copy').attr('value') || '';

            if (couponCode.trim()) {
              allScrapedCoupons.push({
                magazaAdi: storeName,
                baslik: title.trim() || `${storeName} İndirim Kuponu`,
                aciklama: description.trim(),
                kuponKodu: couponCode.trim(),
                paylasanKullaniciId: 'admin',
                olusturulmaTarihi: admin.firestore.Timestamp.now(),
                kaynakTipi: 'web',
                sicakOySayisi: 0,
                sogukOySayisi: 0,
                durum: 'aktif'
              });
            }
          }
          await new Promise(resolve => setTimeout(resolve, 100));
        } catch (detailErr) {
          functions.logger.error(`❌ Error scraping coupon detail ${coupon.detailUrl}:`, detailErr.message);
        }
      }

    } catch (storeErr) {
      functions.logger.error(`❌ Error scraping store ${storeName}:`, storeErr.message);
    }
  }

  functions.logger.info(`✨ Scraping finished. Total coupons scraped: ${allScrapedCoupons.length}`);

  if (allScrapedCoupons.length === 0) {
    functions.logger.warn('⚠️ No coupons scraped. Keeping existing coupons to avoid complete data loss.');
    return { success: false, count: 0, message: 'Hiç kupon çekilemedi. Mevcut kuponlar korunuyor.' };
  }

  // Database update transactionally via batches
  const db = admin.firestore();
  
  // 1. Delete only web-scraped coupons (preserve topluluk/community coupons)
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
  functions.logger.info(`Deleted ${deleteDocs.length} old web-scraped coupons (community coupons preserved).`);

  // 2. Add newly scraped coupons
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

  return { success: true, count: allScrapedCoupons.length };
}

module.exports = {
  scrapeAndSaveCoupons
};
