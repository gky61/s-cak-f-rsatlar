const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');
const GamerGenScraper = require('../scrapers/gamer_gen_scraper');

function runTests() {
  console.log('🧪 GamerGenScraper Tests başlatılıyor...\n');
  const scraper = new GamerGenScraper();

  let passed = 0;
  let failed = 0;
  let total = 0;

  function assert(condition, testName, details = '') {
    total++;
    if (condition) {
      console.log(`  ✅ PASSED: ${testName}${details ? ' → ' + details : ''}`);
      passed++;
    } else {
      console.error(`  ❌ FAILED: ${testName}${details ? ' → ' + details : ''}`);
      failed++;
    }
  }

  // 1. canHandle Tests
  console.log('--- 1. canHandle URL Tests ---');
  assert(scraper.canHandle('https://www.gamer.gen.tr/aoc-q27g41zdf_u56708'), 'Gamer Gen ürün linki');
  assert(scraper.canHandle('https://gamer.gen.tr/gg-horizon_h58071'), 'Gamer Gen hazır sistem linki');
  assert(!scraper.canHandle('https://www.itopya.com/urun_u123'), 'İtopya linki reddedilmeli');
  assert(!scraper.canHandle('https://www.hepsiburada.com/item'), 'Hepsiburada linki reddedilmeli');

  // 2. Product #1: AOC Q27G41ZDF Monitor (Sepette İndirim)
  console.log('\n--- 2. Product #1 (AOC Monitor - Sepette İndirimli) ---');
  const htmlPath1 = path.join(__dirname, '../../scratch/gamer_gen_1.html');
  if (fs.existsSync(htmlPath1)) {
    const html = fs.readFileSync(htmlPath1, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title.includes('AOC Q27G41ZDF'), 'Başlık AOC içermeli', title);
    assert(!title.endsWith('Paylaş'), 'Başlıkta Paylaş eki olmamalı');

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'AOC', 'Marka AOC olmalı', brand);

    const price = scraper.scrapePrice($, html);
    assert(price === 18999, 'İndirimli satış fiyatı 18.999 TL olmalı', price);

    const originalPrice = scraper.scrapeOriginalPrice($, price);
    assert(originalPrice === 23158.63, 'İndirimsiz liste fiyatı 23.158,63 TL olmalı', originalPrice);

    const img = scraper.scrapeImage($, 'https://www.gamer.gen.tr/aoc-q27g41zdf-27%22-240hz-0.03ms-hdmi-dp-adaptive-sync-hdr10-qhd-qd-oled-gaming-monitor_u56708', html);
    assert(img && img.includes('1-063fdf.png'), 'Ürün görseli doğru çekilmeli', img);

    const bc = scraper.scrapeBreadcrumbs($, html);
    assert(bc.includes('Çevre Birimleri') && bc.includes('Monitör'), 'Kategori kırıntıları doğru olmalı', JSON.stringify(bc));

    const rating = scraper.scrapeRating($);
    assert(rating.ratingValue === null && rating.ratingCount === null, 'Rating null olmalı');
  }

  // 3. Product #2: Lian Li Hydro-Shift Cooler (Normal İndirim)
  console.log('\n--- 3. Product #2 (Lian Li Cooler - Normal İndirimli) ---');
  const htmlPath2 = path.join(__dirname, '../../scratch/gamer_gen_2.html');
  if (fs.existsSync(htmlPath2)) {
    const html = fs.readFileSync(htmlPath2, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title.includes('LIAN LI Hydro-Shift'), 'Başlık Lian Li içermeli', title);

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'LIAN LI', 'Marka LIAN LI olmalı', brand);

    const price = scraper.scrapePrice($, html);
    assert(price === 10899, 'İndirimli satış fiyatı 10.899 TL olmalı', price);

    const originalPrice = scraper.scrapeOriginalPrice($, price);
    assert(originalPrice === 11917.48, 'İndirimsiz liste fiyatı 11.917,48 TL olmalı', originalPrice);

    const img = scraper.scrapeImage($, 'https://www.gamer.gen.tr/lian-li-hydro-shift-ii-lcd-c-360cl-360mm-argb-islemci-sivi-sogutucu_u57254', html);
    assert(img && img.includes('1-1-9f0f90.png'), 'Ürün görseli doğru çekilmeli', img);

    const bc = scraper.scrapeBreadcrumbs($, html);
    assert(bc.includes('Soğutucular'), 'Kategori kırıntıları doğru olmalı', JSON.stringify(bc));
  }

  // 4. Product #3: AMD Ryzen 7 5800X3D (Tek Fiyat)
  console.log('\n--- 4. Product #3 (AMD Ryzen 7 - Tek Fiyat) ---');
  const htmlPath3 = path.join(__dirname, '../../scratch/gamer_gen_3.html');
  if (fs.existsSync(htmlPath3)) {
    const html = fs.readFileSync(htmlPath3, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title.includes('AMD Ryzen 7 5800X3D'), 'Başlık Ryzen 7 içermeli', title);

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'AMD', 'Marka AMD olmalı', brand);

    const price = scraper.scrapePrice($, html);
    assert(price === 23267.6, 'Satış fiyatı 23.267,60 TL olmalı', price);

    const originalPrice = scraper.scrapeOriginalPrice($, price);
    assert(originalPrice === null, 'Tek fiyatlı üründe indirimsiz fiyat null olmalı', originalPrice);
  }

  // 5. Product #4: Intel Core Ultra 7 265KF (Sepette İndirim)
  console.log('\n--- 5. Product #4 (Intel Core Ultra 7 - Sepette İndirimli) ---');
  const htmlPath4 = path.join(__dirname, '../../scratch/gamer_gen_4.html');
  if (fs.existsSync(htmlPath4)) {
    const html = fs.readFileSync(htmlPath4, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title.includes('Core Ultra 7 265KF'), 'Başlık Ultra 7 içermeli', title);

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'INTEL', 'Marka INTEL olmalı', brand);

    const price = scraper.scrapePrice($, html);
    assert(price === 15999, 'İndirimli satış fiyatı 15.999 TL olmalı', price);

    const originalPrice = scraper.scrapeOriginalPrice($, price);
    assert(originalPrice === 18896.22, 'İndirimsiz liste fiyatı 18.896,22 TL olmalı', originalPrice);
  }

  // 6. Product #5: Intel Core i5 12400F (Normal İndirim)
  console.log('\n--- 6. Product #5 (Intel Core i5 12400F - Normal İndirimli) ---');
  const htmlPath5 = path.join(__dirname, '../../scratch/gamer_gen_5.html');
  if (fs.existsSync(htmlPath5)) {
    const html = fs.readFileSync(htmlPath5, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title.includes('Core i5 12400F'), 'Başlık i5 12400F içermeli', title);

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'INTEL', 'Marka INTEL olmalı', brand);

    const price = scraper.scrapePrice($, html);
    assert(price === 6799, 'İndirimli satış fiyatı 6.799 TL olmalı', price);

    const originalPrice = scraper.scrapeOriginalPrice($, price);
    assert(originalPrice === 8618.66, 'İndirimsiz liste fiyatı 8.618,66 TL olmalı', originalPrice);
  }

  // 7. Product #6: GG Horizon 5070 V6 Hazır Sistem (_h... Uzantılı)
  console.log('\n--- 7. Product #6 (GG Horizon Hazır Sistem - _h58071) ---');
  const htmlPath6 = path.join(__dirname, '../../scratch/gamer_gen_6.html');
  if (fs.existsSync(htmlPath6)) {
    const html = fs.readFileSync(htmlPath6, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title.includes('GG HORIZON-5070 V6'), 'Başlık Horizon 5070 içermeli', title);

    const price = scraper.scrapePrice($, html);
    assert(price >= 99998.98 && price <= 99999, 'Satış fiyatı 99.998,98 TL olmalı', price);

    const originalPrice = scraper.scrapeOriginalPrice($, price);
    assert(originalPrice === null, 'Tek fiyatlı hazır sistemde indirimsiz fiyat null olmalı', originalPrice);

    const img = scraper.scrapeImage($, 'https://www.gamer.gen.tr/gg-horizon-5070-v6-amd-ryzen-7-7800x3d-msi-geforce-rtx-5070-12g-16gb-ddr5-1tb-nvme-m2-ssd-_h58071', html);
    assert(img && img.includes('1-24fa20.png'), 'Hazır sistem ürün görseli çekilmeli (logo değil)', img);

    const bc = scraper.scrapeBreadcrumbs($, html);
    assert(bc.includes('Hazır Sistemler'), 'Hazır sistem kategorisi tespit edilmeli', JSON.stringify(bc));
  }

  console.log(`\n========================================`);
  console.log(`TEST SONUCU: ${passed}/${total} BAŞARILI (${failed} HATA)`);
  console.log(`========================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
