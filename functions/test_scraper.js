/**
 * Kupon Scraper Test Script
 * 
 * Her 3 kaynağı (DonanimHaber, Kuponla, Kuponburada) canlı olarak test eder.
 * Firestore'a yazmaz, sadece scrape sonuçlarını console'a basar.
 * 
 * Kullanım: node test_scraper.js
 */

const cheerio = require('cheerio');

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const SUPPORTED_STORES = [
  'Trendyol', 'Hepsiburada', 'Amazon', 'N11', 'Pazarama',
  'Teknosa', 'MediaMarkt', 'Mavi', 'DeFacto', 'Zara',
  'Mango', 'Beymen', 'PttAVM', 'İncehesap', 'Idefix',
  'Havit', 'Migros', 'Getir', 'Boyner'
];

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

function resolveStoreName(slug) {
  if (!slug) return null;
  const normalized = slug.toLowerCase().trim();
  return SLUG_TO_STORE[normalized] || null;
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

async function safeFetch(url, timeoutMs = 10000) {
  try {
    const response = await fetch(url, {
      headers: { 'User-Agent': USER_AGENT },
      signal: AbortSignal.timeout(timeoutMs)
    });
    if (!response.ok) {
      console.log(`  ⚠️ HTTP ${response.status} for ${url}`);
      return null;
    }
    return await response.text();
  } catch (err) {
    console.log(`  ⚠️ Fetch error for ${url}: ${err.message}`);
    return null;
  }
}

// ════════════════════════════════════════════════════════════════════
// TEST 1: DonanimHaber
// ════════════════════════════════════════════════════════════════════
async function testDonanimHaber() {
  console.log('\n' + '═'.repeat(70));
  console.log('📡 TEST 1: DonanimHaber (Ana Kaynak)');
  console.log('═'.repeat(70));

  // Sadece 2 mağazayı test et (hız için)
  const testStores = {
    'Trendyol': 'https://indirimkodu.donanimhaber.com/trendyol/',
    'Pazarama': 'https://indirimkodu.donanimhaber.com/pazarama/',
  };

  const coupons = [];
  for (const [storeName, storeUrl] of Object.entries(testStores)) {
    console.log(`\n  🔍 Scraping ${storeName} from ${storeUrl}...`);

    const html = await safeFetch(storeUrl, 10000);
    if (!html) { console.log(`  ❌ Failed to fetch ${storeName}`); continue; }

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
        storeCoupons.push({ detailUrl: dataSingle, couponId: dataCouponId });
      }
    });

    console.log(`  📋 Found ${storeCoupons.length} potential coupons on list page`);

    // Sadece ilk 3 kuponu detay sayfasıyla test et
    const testLimit = Math.min(storeCoupons.length, 3);
    for (let j = 0; j < testLimit; j++) {
      const coupon = storeCoupons[j];
      const finalUrl = `${coupon.detailUrl}?_c=${coupon.couponId}`;
      const detailHtml = await safeFetch(finalUrl, 5000);
      if (detailHtml) {
        const $d = cheerio.load(detailHtml);
        const title = $d('meta[property="og:title"]').attr('content') || '';
        const desc = $d('meta[property="og:description"]').attr('content') || '';
        const code = $d('input#coupon_copy').attr('value') || '';
        if (code.trim()) {
          coupons.push({ magazaAdi: storeName, baslik: title.trim(), kuponKodu: code.trim(), aciklama: desc.trim().substring(0, 60) });
        }
      }
      await new Promise(r => setTimeout(r, 100));
    }
  }

  console.log(`\n  ✅ DonanimHaber sonuç: ${coupons.length} kupon çekildi`);
  coupons.forEach((c, i) => {
    console.log(`     ${i + 1}. [${c.magazaAdi}] ${c.kuponKodu} — ${c.baslik.substring(0, 50)}`);
  });
  return coupons;
}

// ════════════════════════════════════════════════════════════════════
// TEST 2: Kuponla.com
// ════════════════════════════════════════════════════════════════════
async function testKuponla() {
  console.log('\n' + '═'.repeat(70));
  console.log('📡 TEST 2: Kuponla.com (Yardımcı Kaynak)');
  console.log('═'.repeat(70));

  const allCoupons = [];

  for (const [pageNum, pageUrl] of [
    [1, 'https://kuponla.com/son-eklenen-kuponlar/'],
    [2, 'https://kuponla.com/son-eklenen-kuponlar/page/2/']
  ]) {
    console.log(`\n  🔍 Fetching page ${pageNum}: ${pageUrl}`);
    const html = await safeFetch(pageUrl, 15000);
    if (!html) { console.log(`  ❌ Page ${pageNum} failed`); continue; }

    const $ = cheerio.load(html);
    const pageCoupons = [];

    $('div.coupon-item').each((i, el) => {
      try {
        const $item = $(el);
        const codeButton = $item.find('a.coupon-code[data-code]');
        if (codeButton.length === 0) return;

        const couponCode = (codeButton.attr('data-code') || '').trim();
        if (!couponCode) return;

        const storeNameText = $item.find('div.store-name > a').text().trim();
        const storeName = resolveStoreFromKuponlaName(storeNameText);

        const titleLink = $item.find('h3.coupon-title > a');
        const title = (titleLink.attr('title') || titleLink.text() || '').trim();

        pageCoupons.push({
          magazaAdi: storeName || `[${storeNameText}]`,
          kuponKodu: couponCode,
          baslik: title.substring(0, 60),
          desteklenen: storeName ? '✅' : '❌'
        });
      } catch (e) { /* skip */ }
    });

    console.log(`  📋 Page ${pageNum}: Found ${pageCoupons.length} code coupons (total items on page: ${$('div.coupon-item').length})`);
    
    // Sadece desteklenen mağazaları göster
    const supported = pageCoupons.filter(c => c.desteklenen === '✅');
    const unsupported = pageCoupons.filter(c => c.desteklenen === '❌');
    console.log(`     ✅ Desteklenen: ${supported.length} | ❌ Desteklenmeyen: ${unsupported.length}`);
    
    supported.forEach((c, i) => {
      console.log(`     ${i + 1}. [${c.magazaAdi}] ${c.kuponKodu} — ${c.baslik}`);
    });

    if (unsupported.length > 0) {
      console.log(`     (Atlanan mağazalar: ${unsupported.map(c => c.magazaAdi).join(', ')})`);
    }

    allCoupons.push(...supported);
    if (pageNum === 1) await new Promise(r => setTimeout(r, 200));
  }

  console.log(`\n  ✅ Kuponla.com sonuç: ${allCoupons.length} desteklenen kupon çekildi`);
  return allCoupons;
}

// ════════════════════════════════════════════════════════════════════
// TEST 3: Kuponburada.com
// ════════════════════════════════════════════════════════════════════
async function testKuponburada() {
  console.log('\n' + '═'.repeat(70));
  console.log('📡 TEST 3: Kuponburada.com (Yardımcı Kaynak)');
  console.log('═'.repeat(70));

  const pageUrl = 'https://www.kuponburada.com/kesfet/yeni-indirim-kuponlari/';
  console.log(`\n  🔍 Fetching: ${pageUrl}`);
  
  const html = await safeFetch(pageUrl, 15000);
  if (!html) {
    console.log('  ❌ Failed to fetch page');
    return [];
  }

  const $ = cheerio.load(html);
  const totalItems = $('li[data-coupon-item]').length;
  const codeItems = $('li[data-coupon-type="code"]').length;
  const dealItems = totalItems - codeItems;
  
  console.log(`  📋 Total items: ${totalItems} (code: ${codeItems}, deal/campaign: ${dealItems})`);

  const coupons = [];

  $('li[data-coupon-type="code"]').each((i, el) => {
    try {
      const $item = $(el);
      
      const expired = $item.find('article').attr('data-coupon-expired');
      if (expired === '1') return;

      const couponButton = $item.find('a.coupon-button');
      const ariaLabel = couponButton.attr('aria-label') || '';
      const codeMatch = ariaLabel.match(/Kod:\s*([^,]+)/);
      const couponCode = codeMatch ? codeMatch[1].trim() : '';
      if (!couponCode) return;

      const brandSlug = couponButton.attr('data-brand-slug') || '';
      const storeName = resolveStoreName(brandSlug);

      const title = $item.find('h3').first().text().trim();
      
      const srOnlyDivs = $item.find('div.sr-only');
      let description = '';
      if (srOnlyDivs.length > 0) {
        description = srOnlyDivs.first().text().trim();
      }
      if (!description) {
        description = $item.find('p.text-gray-600').first().text().trim();
      }

      coupons.push({
        magazaAdi: storeName || `[slug: ${brandSlug}]`,
        kuponKodu: couponCode,
        baslik: title.substring(0, 60),
        aciklama: description.substring(0, 60),
        desteklenen: storeName ? '✅' : '❌'
      });
    } catch (e) { /* skip */ }
  });

  const supported = coupons.filter(c => c.desteklenen === '✅');
  const unsupported = coupons.filter(c => c.desteklenen === '❌');
  
  console.log(`\n  ✅ Desteklenen: ${supported.length} | ❌ Desteklenmeyen: ${unsupported.length}`);
  supported.forEach((c, i) => {
    console.log(`     ${i + 1}. [${c.magazaAdi}] ${c.kuponKodu} — ${c.baslik}`);
    console.log(`        Açıklama: ${c.aciklama}...`);
  });

  if (unsupported.length > 0) {
    console.log(`     (Atlanan mağazalar: ${unsupported.map(c => c.magazaAdi).join(', ')})`);
  }

  console.log(`\n  ✅ Kuponburada.com sonuç: ${supported.length} desteklenen kupon çekildi`);
  return supported;
}

// ════════════════════════════════════════════════════════════════════
// MÜKERRER KONTROLÜ TESTİ
// ════════════════════════════════════════════════════════════════════
function testDeduplication(dhCoupons, kuponlaCoupons, kuponburadaCoupons) {
  console.log('\n' + '═'.repeat(70));
  console.log('🔄 TEST 4: Mükerrer Kontrol (Deduplication)');
  console.log('═'.repeat(70));

  const seenCodes = new Set();
  const final = [];
  let dhCount = 0, klCount = 0, kbCount = 0;
  let klDup = 0, kbDup = 0;

  for (const c of dhCoupons) {
    const key = c.kuponKodu.toUpperCase();
    if (!seenCodes.has(key)) { seenCodes.add(key); final.push(c); dhCount++; }
  }
  for (const c of kuponlaCoupons) {
    const key = c.kuponKodu.toUpperCase();
    if (!seenCodes.has(key)) { seenCodes.add(key); final.push(c); klCount++; }
    else { klDup++; }
  }
  for (const c of kuponburadaCoupons) {
    const key = c.kuponKodu.toUpperCase();
    if (!seenCodes.has(key)) { seenCodes.add(key); final.push(c); kbCount++; }
    else { kbDup++; }
  }

  console.log(`\n  📊 Kaynak Bazlı Sonuçlar:`);
  console.log(`     DonanimHaber : ${dhCount} benzersiz kupon`);
  console.log(`     Kuponla.com  : ${klCount} yeni + ${klDup} mükerrer`);
  console.log(`     Kuponburada  : ${kbCount} yeni + ${kbDup} mükerrer`);
  console.log(`     ─────────────────────────────`);
  console.log(`     TOPLAM       : ${final.length} benzersiz kupon`);
  
  return final;
}

// ════════════════════════════════════════════════════════════════════
// ANA TEST ÇALIŞTIRICI
// ════════════════════════════════════════════════════════════════════
async function runAllTests() {
  console.log('🚀 Kupon Scraper Test Suite Başlatılıyor...');
  console.log(`📅 ${new Date().toLocaleString('tr-TR')}`);

  const dhResults = await testDonanimHaber();
  const klResults = await testKuponla();
  const kbResults = await testKuponburada();

  testDeduplication(dhResults, klResults, kbResults);

  console.log('\n' + '═'.repeat(70));
  console.log('✅ TÜM TESTLER TAMAMLANDI');
  console.log('═'.repeat(70));
}

runAllTests().catch(err => {
  console.error('❌ Test suite failed:', err);
  process.exit(1);
});
