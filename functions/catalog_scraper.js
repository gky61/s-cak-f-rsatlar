const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cheerio = require('cheerio');

const STORES = [
  { code: 'a101', name: 'A101', url: 'https://www.akakce.com/brosurler/a101' },
  { code: 'bim', name: 'BİM', url: 'https://www.akakce.com/brosurler/bim' },
  { code: 'sok', name: 'ŞOK', url: 'https://www.akakce.com/brosurler/sok' },
  { code: 'migros', name: 'Migros', url: 'https://www.akakce.com/brosurler/migros' },
  { code: 'carrefoursa', name: 'CarrefourSA', url: 'https://www.akakce.com/brosurler/carrefoursa' },
  { code: 'cagri', name: 'Çağrı', url: 'https://www.akakce.com/brosurler/cagrihipermarket' },
  { code: 'happycenter', name: 'HappyCenter', url: 'https://www.akakce.com/brosurler/happy-center' },
  { code: 'macrocenter', name: 'MacroCenter', url: 'https://www.akakce.com/brosurler/macrocenter' },
  { code: 'getirbuyuk', name: 'GetirBüyük', url: 'https://www.akakce.com/brosurler/getirbuyuk' },
  { code: 'file', name: 'File', url: 'https://www.akakce.com/brosurler/filemarket' },
  { code: 'hakmar', name: 'Hakmar', url: 'https://www.akakce.com/brosurler/hakmarexpress' },
  { code: 'gratis', name: 'Gratis', url: 'https://www.akakce.com/brosurler/gratis' },
  { code: 'watsons', name: 'Watsons', url: 'https://www.akakce.com/brosurler/watsons' },
  { code: 'kooperatifmarket', name: 'Kooperatif Market', url: 'https://www.akakce.com/brosurler/kooperatifmarket' },
  { code: 'metro', name: 'Metro', url: 'https://www.akakce.com/brosurler/metro-tr' },
  { code: 'bizim', name: 'Bizim', url: 'https://www.akakce.com/brosurler/bizimtoptan' },
  { code: 'teknosa', name: 'Teknosa', url: 'https://www.akakce.com/brosurler/teknosacom' },
  { code: 'vatan', name: 'Vatan', url: 'https://www.akakce.com/brosurler/vatanbilgisayar' }
];

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const MONTHS_MAP = {
  'ocak': 0, 'subat': 1, 'şubat': 1, 'mart': 2, 'nisan': 3,
  'mayis': 4, 'mayıs': 4, 'haziran': 5, 'temmuz': 6, 'agustos': 7, 'ağustos': 7,
  'eylul': 8, 'eylül': 8, 'ekim': 9, 'kasim': 10, 'kasım': 10, 'aralik': 11, 'aralık': 11
};

const WEEKDAYS_MAP = {
  'pazartesi': 1, 'sali': 2, 'salı': 2, 'carsamba': 3, 'çarşamba': 3,
  'persembe': 4, 'perşembe': 4, 'cuma': 5, 'cumartesi': 6, 'pazar': 0
};

/**
 * Parses start date from relative URL.
 * Example: /brosurler/bim-24-mart-2026-aktuel-katalogu-indirimli-urunler-56190
 */
function parseDateFromUrl(url) {
  const match = url.match(/(\d+)-([a-zA-ZğüşöçıİĞÜŞÖÇI]+)-(\d{4})/);
  if (match) {
    const day = parseInt(match[1], 10);
    const monthStr = match[2].toLowerCase();
    const year = parseInt(match[3], 10);
    const month = MONTHS_MAP[monthStr] !== undefined ? MONTHS_MAP[monthStr] : 0;
    return new Date(year, month, day);
  }
  return new Date();
}

/**
 * Calculates end date based on remaining time text.
 */
function calculateEndDate(baslangicTarihi, timeRemainingText) {
  const normalizedText = timeRemainingText.toLowerCase().trim();
  const today = new Date();
  
  // "X gün kaldı"
  const gunMatch = normalizedText.match(/(\d+)\s+gün\s+kaldı/);
  if (gunMatch) {
    const days = parseInt(gunMatch[1], 10);
    const endDate = new Date(today.getTime() + days * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "X hafta kaldı"
  const haftaMatch = normalizedText.match(/(\d+)\s+hafta\s+kaldı/);
  if (haftaMatch) {
    const weeks = parseInt(haftaMatch[1], 10);
    const endDate = new Date(today.getTime() + weeks * 7 * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "X ay kaldı"
  const ayMatch = normalizedText.match(/(\d+)\s+ay\s+kaldı/);
  if (ayMatch) {
    const months = parseInt(ayMatch[1], 10);
    const endDate = new Date(today.getTime() + months * 30 * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "1 ay sonra başlıyor" etc.
  if (normalizedText.includes('başlıyor')) {
    const endDate = new Date(baslangicTarihi.getTime() + 7 * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "Bugün son" or "Bugün son gün"
  if (normalizedText.includes('bugün son')) {
    const endDate = new Date(today);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "Yarın son"
  if (normalizedText.includes('yarın son')) {
    const endDate = new Date(today.getTime() + 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "Son gün Pazartesi" / "Son gün Salı" vb.
  const sonGunMatch = normalizedText.match(/son\s+gün\s+([a-zA-ZğüşöçıİĞÜŞÖÇI]+)/);
  if (sonGunMatch) {
    const dayName = sonGunMatch[1].toLowerCase();
    if (WEEKDAYS_MAP[dayName] !== undefined) {
      const targetDay = WEEKDAYS_MAP[dayName];
      const currentDay = today.getDay();
      let daysToAdd = (targetDay - currentDay + 7) % 7;
      if (daysToAdd === 0) daysToAdd = 7;
      const endDate = new Date(today.getTime() + daysToAdd * 24 * 60 * 60 * 1000);
      endDate.setHours(23, 59, 59, 999);
      return endDate;
    }
  }

  // Fallback: başlangıç tarihinden 7 gün sonra
  const endDate = new Date(baslangicTarihi.getTime() + 7 * 24 * 60 * 60 * 1000);
  endDate.setHours(23, 59, 59, 999);
  return endDate;
}

/**
 * Main scraper function for active catalog brochures.
 */
async function scrapeAndSaveCatalogs() {
  functions.logger.info('🚀 Active Catalog scraping process started...');
  const allScrapedCatalogs = [];

  for (const store of STORES) {
    try {
      functions.logger.info(`🔍 Fetching catalog list for ${store.name} from ${store.url}...`);
      
      const response = await fetch(store.url, {
        headers: { 'User-Agent': USER_AGENT },
        signal: AbortSignal.timeout(15000)
      });

      if (!response.ok) {
        functions.logger.warn(`⚠️ Failed to fetch catalog page for ${store.name}. Status: ${response.status}`);
        continue;
      }

      const html = await response.text();
      const $ = cheerio.load(html);

      const catalogItems = [];

      // Parse catalog lists inside ul#BLI
      $('ul#BLI li').each((i, el) => {
        const aTag = $(el).find('a');
        const href = aTag.attr('href') || '';
        
        if (href.startsWith('/brosurler/')) {
          // Extract cover thumbnail from style (background: url(...))
          const imgStyle = aTag.find('.dt img').attr('style') || '';
          const bgUrlMatch = imgStyle.match(/url\((?:&quot;|"|')?([^)'"]+?)(?:&quot;|"|')?\)/);
          let coverImage = '';
          if (bgUrlMatch) {
            coverImage = bgUrlMatch[1];
            if (coverImage.startsWith('//')) {
              coverImage = 'https:' + coverImage;
            }
          }

          // Suffix catalog title
          const titleSuffix = aTag.find('.blid .bn').text().trim() || 'Aktüel Kataloğu';
          const timeRemainingText = aTag.find('span.b').text().trim();
          
          // Brochure ID from url end
          const idMatch = href.match(/(\d+)$/);
          const brochureId = idMatch ? idMatch[1] : '';

          if (brochureId) {
            catalogItems.push({
              brochureId,
              href,
              coverImage,
              titleSuffix,
              timeRemainingText
            });
          }
        }
      });

      functions.logger.info(`Found ${catalogItems.length} brochures for ${store.name}.`);

      // Scrape detail pages sequentially
      for (const item of catalogItems) {
        try {
          const detailUrl = `https://www.akakce.com${item.href}`;
          functions.logger.info(`   📄 Scraping detail page: ${detailUrl}`);

          const detailResponse = await fetch(detailUrl, {
            headers: { 'User-Agent': USER_AGENT },
            signal: AbortSignal.timeout(10000)
          });

          if (detailResponse.ok) {
            const detailHtml = await detailResponse.text();
            const $detail = cheerio.load(detailHtml);
            
            const sayfaResimleri = [];
            $detail('#BP_W .p img').each((i, el) => {
              let src = $(el).attr('data-src') || $(el).attr('src');
              if (src && !src.includes('t.gif')) {
                if (src.startsWith('//')) {
                  src = 'https:' + src;
                }
                // Convert low-res thumbnail paths (/l/, /y/, /m/) to high-res upload path (/u/)
                src = src.replace('/_bro/l/', '/_bro/u/')
                         .replace('/_bro/y/', '/_bro/u/')
                         .replace('/_bro/m/', '/_bro/u/');
                
                sayfaResimleri.push(src);
              }
            });

            if (sayfaResimleri.length > 0) {
              const baslangicTarihi = parseDateFromUrl(item.href);
              const bitisTarihi = calculateEndDate(baslangicTarihi, item.timeRemainingText);

              // Use first page image as cover if cover thumbnail is empty or a placeholder
              let finalCover = (item.coverImage && !item.coverImage.includes('t.gif'))
                ? item.coverImage
                : sayfaResimleri[0];

              if (finalCover.startsWith('//')) {
                finalCover = 'https:' + finalCover;
              }
              // Convert to large thumbnail path (/l/) for fast grid listing
              finalCover = finalCover.replace('/_bro/u/', '/_bro/l/')
                                     .replace('/_bro/y/', '/_bro/l/')
                                     .replace('/_bro/m/', '/_bro/l/');

              allScrapedCatalogs.push({
                katalogId: `${store.code}_${item.brochureId}`,
                magazaKodu: store.code,
                katalogBasligi: item.titleSuffix,
                baslangicTarihi,
                bitisTarihi,
                sayfaResimleri,
                kapakResmi: finalCover
              });
            } else {
              functions.logger.warn(`   ⚠️ No pages found inside brochure ${item.brochureId}. Skipping.`);
            }
          }
          // Delay to prevent rate limit
          await new Promise(resolve => setTimeout(resolve, 150));
        } catch (detailErr) {
          functions.logger.error(`❌ Error scraping brochure detail ${item.brochureId}:`, detailErr.message);
        }
      }

    } catch (storeErr) {
      functions.logger.error(`❌ Error scraping store ${store.name}:`, storeErr.message);
    }
  }

  functions.logger.info(`✨ Scraping completed. Total catalogs scraped: ${allScrapedCatalogs.length}`);

  if (allScrapedCatalogs.length === 0) {
    functions.logger.warn('⚠️ No catalogs scraped. Keeping existing data to prevent blank screen.');
    return { success: false, count: 0, message: 'Hiç katalog kazınamadı.' };
  }

  const db = admin.firestore();

  // 1. Delete all existing catalogs to ensure fresh reload (matching coupons scraper)
  functions.logger.info('🧹 Deleting all existing catalogs from Firestore...');
  const querySnapshot = await db.collection('kataloglar').get();
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
  functions.logger.info(`Deleted ${deleteDocs.length} old catalogs.`);

  // 2. Add newly scraped catalogs
  functions.logger.info('💾 Saving new catalogs to Firestore...');
  const writeChunks = [];
  for (let i = 0; i < allScrapedCatalogs.length; i += 500) {
    writeChunks.push(allScrapedCatalogs.slice(i, i + 500));
  }

  for (const chunk of writeChunks) {
    const batch = db.batch();
    chunk.forEach((catalog) => {
      const docRef = db.collection('kataloglar').doc(catalog.katalogId);
      
      // Convert Date objects to Firestore Timestamp
      const dataToSave = {
        ...catalog,
        baslangicTarihi: admin.firestore.Timestamp.fromDate(catalog.baslangicTarihi),
        bitisTarihi: admin.firestore.Timestamp.fromDate(catalog.bitisTarihi),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.set(docRef, dataToSave);
    });
    await batch.commit();
  }

  functions.logger.info('🎉 Catalog sync finished successfully.');
  return { success: true, count: allScrapedCatalogs.length };
}

module.exports = {
  scrapeAndSaveCatalogs
};
