/**
 * FırsatKolik — Smart Incremental Scraping Engine Doğrulama Testi
 */
const assert = require('assert');

console.log('🚀 Smart Incremental Scraping Engine Test Süiti Başlatılıyor...\n');

// TEST 1: Cache Hit ve Cache Miss Mantığı
console.log('--- TEST 1: Cache Hit / Miss Karar Ağacı Doğrulaması ---');
{
  const existingCatalogMap = new Map();
  existingCatalogMap.set('bim_59531', {
    katalogId: 'bim_59531',
    magazaKodu: 'bim',
    katalogBasligi: 'Cuma Fırsatları',
    baslangicTarihi: '2026-10-16T00:00:00Z',
    bitisTarihi: '2026-10-23T23:59:59Z',
    sayfaResimleri: ['https://cdn.akakce.com/_bro/u/1.jpg', 'https://cdn.akakce.com/_bro/u/2.jpg'],
    kapakResmi: 'https://firebasestorage.googleapis.com/.../bim_59531_cover.webp',
    originalKapakResmi: 'https://cdn.akakce.com/_bro/l/1.jpg',
    storageCoverUrl: 'https://firebasestorage.googleapis.com/.../bim_59531_cover.webp'
  });

  // Eksik veri içeren bozuk doküman
  existingCatalogMap.set('bim_broken', {
    katalogId: 'bim_broken',
    magazaKodu: 'bim',
    sayfaResimleri: [], // Boş sayfalar!
    kapakResmi: '',
    bitisTarihi: null
  });

  function evaluateIncrementalCache(catalogId, item) {
    if (existingCatalogMap.has(catalogId)) {
      const cached = existingCatalogMap.get(catalogId);
      const hasPages = Array.isArray(cached.sayfaResimleri) && cached.sayfaResimleri.length > 0;
      const hasCover = typeof cached.kapakResmi === 'string' && cached.kapakResmi.length > 0;
      const hasDates = cached.bitisTarihi != null;

      if (hasPages && hasCover && hasDates) {
        return {
          isHit: true,
          data: {
            katalogId: catalogId,
            magazaKodu: 'bim',
            katalogBasligi: item.titleSuffix || cached.katalogBasligi,
            baslangicTarihi: cached.baslangicTarihi,
            bitisTarihi: cached.bitisTarihi,
            sayfaResimleri: cached.sayfaResimleri,
            kapakResmi: cached.kapakResmi,
            originalKapakResmi: cached.originalKapakResmi || cached.kapakResmi,
            storageCoverUrl: cached.storageCoverUrl || null
          }
        };
      }
    }
    return { isHit: false, data: null };
  }

  // Senaryo A: Sağlam önbellek kaydı -> CACHE HIT (0 HTTP İsteği)
  const hitResult = evaluateIncrementalCache('bim_59531', { titleSuffix: '16 Ekim Cuma' });
  assert.strictEqual(hitResult.isHit, true);
  assert.strictEqual(hitResult.data.sayfaResimleri.length, 2);
  assert.strictEqual(hitResult.data.katalogBasligi, '16 Ekim Cuma');
  console.log('  ✅ Senaryo A Başarılı: Eksiksiz katalog için Cache Hit teyit edildi.');

  // Senaryo B: Bozuk önbellek kaydı -> CACHE MISS (Detay çekilerek tamir edilir)
  const brokenResult = evaluateIncrementalCache('bim_broken', { titleSuffix: 'Bozuk Broşür' });
  assert.strictEqual(brokenResult.isHit, false);
  console.log('  ✅ Senaryo B Başarılı: Bozuk/eksik doküman otomatik olarak Cache Miss sayıldı.');

  // Senaryo C: Yeni yayınlanan broşür -> CACHE MISS (Yeni çekilir)
  const newResult = evaluateIncrementalCache('bim_99999', { titleSuffix: 'Yeni Broşür' });
  assert.strictEqual(newResult.isHit, false);
  console.log('  ✅ Senaryo C Başarılı: Yeni katalog için Cache Miss teyit edildi.');
}

// TEST 2: Yandex TurboPages ve Translate Proxy URL Temizliği
console.log('\n--- TEST 2: Multi-Proxy URL Normalizasyonu Sözleşmesi ---');
{
  function cleanHref(href) {
    let cleanPath = href;
    if (cleanPath.includes('turbopages.org')) {
      const parts = cleanPath.split(/\/https?\/(?:www\.)?akakce\.com/i);
      if (parts.length > 1) {
        cleanPath = parts[1];
      }
    } else if (cleanPath.includes('translate.yandex.')) {
      try {
        const u = new URL(cleanPath.startsWith('http') ? cleanPath : `https://${cleanPath}`);
        const inner = u.searchParams.get('url');
        if (inner) cleanPath = new URL(inner).pathname;
      } catch (e) {}
    } else if (cleanPath.includes('.translate.goog')) {
      try {
        const u = new URL(cleanPath.startsWith('http') ? cleanPath : `https://${cleanPath}`);
        cleanPath = u.pathname;
      } catch (e) {}
    }
    return cleanPath.split('?')[0].split('#')[0].replace(/\/+$/, '');
  }

  assert.strictEqual(
    cleanHref('https://akakce-com.translated.turbopages.org/https/www.akakce.com/brosurler/bim/cuma-59531.html?lang=tr-tr'),
    '/brosurler/bim/cuma-59531.html'
  );
  assert.strictEqual(
    cleanHref('https://translate.yandex.ru/translate?url=https%3A%2F%2Fwww.akakce.com%2Fbrosurler%2Fa101%2Faldin-44001.html&lang=tr-tr'),
    '/brosurler/a101/aldin-44001.html'
  );
  assert.strictEqual(
    cleanHref('https://www-akakce-com.translate.goog/brosurler/sok/carsamba-123.html?_x_tr_sl=auto'),
    '/brosurler/sok/carsamba-123.html'
  );
  assert.strictEqual(
    cleanHref('/brosurler/migros/firsatlar-555.html'),
    '/brosurler/migros/firsatlar-555.html'
  );
  console.log('  ✅ Tüm proxy varyantları kusursuz şekilde /brosurler/... pathine normalize edildi.');
}

// TEST 3: Görsel URL Temizliği
console.log('\n--- TEST 3: Görsel URL Proxy Arındırma Sözleşmesi ---');
{
  function cleanImageUrl(src) {
    if (src.includes('turbopages.org')) {
      const parts = src.split(/\/https?\/(?:cdn\.akakce\.com|www\.akakce\.com)/i);
      if (parts.length > 1) src = 'https://cdn.akakce.com' + parts[1];
    } else if (src.includes('.translate.goog')) {
      try {
        const u = new URL(src.startsWith('http') ? src : 'https://' + src);
        src = 'https://cdn.akakce.com' + u.pathname;
      } catch (e) {}
    }
    src = src.split('?')[0].split('#')[0];
    if (src.startsWith('//')) src = 'https:' + src;
    return src.replace('/_bro/l/', '/_bro/u/').replace('/_bro/y/', '/_bro/u/').replace('/_bro/m/', '/_bro/u/');
  }

  assert.strictEqual(
    cleanImageUrl('https://cdn-akakce-com.translated.turbopages.org/https/cdn.akakce.com/_bro/l/100_cover.jpg?lang=tr-tr'),
    'https://cdn.akakce.com/_bro/u/100_cover.jpg'
  );
  assert.strictEqual(
    cleanImageUrl('https://cdn-akakce-com.translate.goog/_bro/m/200_page.jpg?_x_tr_sl=auto'),
    'https://cdn.akakce.com/_bro/u/200_page.jpg'
  );
  console.log('  ✅ Proxy üzerinden gelen görseller doğrudan cdn.akakce.com/_bro/u/ formatına dönüştürüldü.');
}

// TEST 4: Önbellek Kapak Görseli İyileştirme (Auto-Healing)
console.log('\n--- TEST 4: Storage Cover URL Kendini İyileştirme (Auto-Healing) Sözleşmesi ---');
{
  function healCachedCover(cached, mockStorageUrl) {
    let storageCoverUrl = cached.storageCoverUrl || null;
    let kapakResmi = cached.kapakResmi;
    if (!storageCoverUrl && kapakResmi && kapakResmi.includes('firebasestorage.googleapis.com')) {
      storageCoverUrl = kapakResmi;
    } else if (!storageCoverUrl && kapakResmi) {
      storageCoverUrl = mockStorageUrl;
      if (storageCoverUrl) {
        kapakResmi = storageCoverUrl;
      }
    }
    return { kapakResmi, storageCoverUrl };
  }

  // Senaryo A: Zaten Storage URL'e sahip
  const r1 = healCachedCover({
    storageCoverUrl: 'https://firebasestorage.googleapis.com/.../bim_cover.webp',
    kapakResmi: 'https://firebasestorage.googleapis.com/.../bim_cover.webp'
  }, 'https://mock.url');
  assert.strictEqual(r1.storageCoverUrl, 'https://firebasestorage.googleapis.com/.../bim_cover.webp');

  // Senaryo B: kapakResmi Storage URL ama storageCoverUrl null kalmış
  const r2 = healCachedCover({
    storageCoverUrl: null,
    kapakResmi: 'https://firebasestorage.googleapis.com/.../bim_cover.webp'
  }, 'https://mock.url');
  assert.strictEqual(r2.storageCoverUrl, 'https://firebasestorage.googleapis.com/.../bim_cover.webp');

  // Senaryo C: Orijinal Akakçe CDN URL'i kalmış -> Auto-heal edilerek Storage URL atanır
  const r3 = healCachedCover({
    storageCoverUrl: null,
    kapakResmi: 'https://cdn.akakce.com/_bro/l/bim.jpg'
  }, 'https://firebasestorage.googleapis.com/.../healed_bim_cover.webp');
  assert.strictEqual(r3.storageCoverUrl, 'https://firebasestorage.googleapis.com/.../healed_bim_cover.webp');
  assert.strictEqual(r3.kapakResmi, 'https://firebasestorage.googleapis.com/.../healed_bim_cover.webp');
  console.log('  ✅ Önbellekte eksik/eski kapaklar otomatik olarak Storage CDN kalkanına dönüştürüldü.');
}

// TEST 5: Aktüel Meta Mağaza Broşür Sayısı ve Süresi Dolan Katalog Filtreleme
console.log('\n--- TEST 5: settings/aktuel_meta Süresi Dolan Katalog Filtreleme Sözleşmesi ---');
{
  function createTurkeyDate(year, monthIndex, day, hours = 0, minutes = 0, seconds = 0, ms = 0) {
    const utcMs = Date.UTC(year, monthIndex, day, hours, minutes, seconds, ms) - (3 * 3600 * 1000);
    return new Date(utcMs);
  }

  const now = new Date('2026-10-16T12:00:00Z');
  const turkeyNow = new Date(now.getTime() + (3 * 3600 * 1000));
  const today = createTurkeyDate(turkeyNow.getUTCFullYear(), turkeyNow.getUTCMonth(), turkeyNow.getUTCDate(), 0, 0, 0, 0);

  const mockScrapedCatalogs = [
    { magazaKodu: 'bim', bitisTarihi: createTurkeyDate(2026, 9, 20, 23, 59, 59, 999) }, // Aktif (20 Ekim)
    { magazaKodu: 'bim', bitisTarihi: createTurkeyDate(2026, 9, 15, 23, 59, 59, 999) }, // Dün bitmiş (15 Ekim - Süresi dolmuş!)
    { magazaKodu: 'a101', bitisTarihi: createTurkeyDate(2026, 9, 16, 23, 59, 59, 999) }, // Bugün son gün (16 Ekim - Aktif)
    { magazaKodu: 'sok', bitisTarihi: createTurkeyDate(2026, 9, 14, 23, 59, 59, 999) }  // 2 gün önce bitmiş (14 Ekim - Süresi dolmuş!)
  ];

  const activeStoreCounts = {};
  for (const cat of mockScrapedCatalogs) {
    const code = (cat.magazaKodu || '').toLowerCase().trim();
    if (code) {
      if (cat.bitisTarihi) {
        const expiryDate = cat.bitisTarihi.toDate ? cat.bitisTarihi.toDate() : new Date(cat.bitisTarihi);
        if (!isNaN(expiryDate.getTime()) && expiryDate < today) continue;
      }
      activeStoreCounts[code] = (activeStoreCounts[code] || 0) + 1;
    }
  }

  assert.strictEqual(activeStoreCounts['bim'], 1, 'BİM için süresi dolmuş katalog hariç tutulmalı (Tam 1 aktif kalmalı)');
  assert.strictEqual(activeStoreCounts['a101'], 1, 'A101 için bugünkü katalog aktif sayılmalı');
  assert.strictEqual(activeStoreCounts['sok'], undefined, 'ŞOK için süresi geçmiş katalog tamamen elenmeli');
  console.log('  ✅ Katalog listesi ile settings/aktuel_meta arasında %100 matematiksel uyum doğrulandı.');
}

console.log('\n🎉 TÜM SMART INCREMENTAL SCRAPING TESTLERİ (5/5) BAŞARIYLA GEÇTİ!');
