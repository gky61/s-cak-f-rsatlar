const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');
const GamingGenScraper = require('../scrapers/gaming_gen_scraper');

function runTests() {
  console.log('🧪 GamingGenScraper Tests başlatılıyor...\n');
  const scraper = new GamingGenScraper();

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
  assert(scraper.canHandle('https://www.gaming.gen.tr/urun/542776/pc-hocasi-gg10/'), 'Gaming Gen ürün linki');
  assert(scraper.canHandle('https://gaming.gen.tr/urun/612335/ultima-5080/'), 'Gaming Gen www olmadan');
  assert(!scraper.canHandle('https://www.gamer.gen.tr/urun_u123'), 'Gamer Gen linki reddedilmeli');
  assert(!scraper.canHandle('https://www.itopya.com/urun_u123'), 'İtopya linki reddedilmeli');
  assert(!scraper.canHandle('https://www.hepsiburada.com/item'), 'Hepsiburada linki reddedilmeli');

  // 2. Product #1: PC HOCASI-GG10
  console.log('\n--- 2. Product #1 (PC HOCASI-GG10) ---');
  const htmlPath1 = path.join(__dirname, '../../scratch/gaming_gen_1.html');
  if (fs.existsSync(htmlPath1)) {
    const html = fs.readFileSync(htmlPath1, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title && title.includes('PC HOCASI-GG10'), 'Başlık PC HOCASI-GG10 içermeli', title);

    const price = scraper.scrapePrice($, html);
    assert(price >= 48498.98 && price <= 48499.00, 'Satış fiyatı 48.498,99 TL olmalı', price);

    const rating = scraper.scrapeRating($);
    assert(rating.ratingValue >= 4.8 && rating.ratingValue <= 4.9, 'Rating 4.8 veya 4.9 olmalı', rating.ratingValue);
    assert(rating.ratingCount === 27, 'Değerlendirme sayısı 27 olmalı', rating.ratingCount);

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'Powered by ASUS', 'Marka Powered by ASUS olmalı', brand);

    const img = scraper.scrapeImage($, 'https://www.gaming.gen.tr/urun/542776/pc-hocasi-gg10/', html);
    assert(img && img.includes('.jpg'), 'Ürün görseli çekilmeli', img);

    const bc = scraper.scrapeBreadcrumbs($, html);
    assert(bc.includes('Tavsiye Sistemler'), 'Kategori kırıntısı Tavsiye Sistemler içermeli', JSON.stringify(bc));
  }

  // 3. Product #2: ULTIMA-5080
  console.log('\n--- 3. Product #2 (ULTIMA-5080) ---');
  const htmlPath2 = path.join(__dirname, '../../scratch/gaming_gen_2.html');
  if (fs.existsSync(htmlPath2)) {
    const html = fs.readFileSync(htmlPath2, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title && title.includes('ULTIMA-5080'), 'Başlık ULTIMA-5080 içermeli', title);

    const price = scraper.scrapePrice($, html);
    assert(price >= 159999.00 && price <= 159999.01, 'Satış fiyatı 159.999,01 TL olmalı', price);

    const rating = scraper.scrapeRating($);
    assert(rating.ratingValue === 4.5, 'Rating 4.5 olmalı', rating.ratingValue);
    assert(rating.ratingCount === 2, 'Değerlendirme sayısı 2 olmalı', rating.ratingCount);

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'Powered by ASUS', 'Marka Powered by ASUS olmalı', brand);
  }

  // 4. Product #3: IMOLA-5060
  console.log('\n--- 4. Product #3 (IMOLA-5060) ---');
  const htmlPath3 = path.join(__dirname, '../../scratch/gaming_gen_3.html');
  if (fs.existsSync(htmlPath3)) {
    const html = fs.readFileSync(htmlPath3, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title && title.includes('IMOLA-5060'), 'Başlık IMOLA-5060 içermeli', title);

    const price = scraper.scrapePrice($, html);
    assert(price >= 57998.99 && price <= 57999.00, 'Satış fiyatı 57.999,00 TL olmalı', price);

    const rating = scraper.scrapeRating($);
    assert(rating.ratingValue === 4.9, 'Rating 4.9 olmalı', rating.ratingValue);
    assert(rating.ratingCount === 373, 'Değerlendirme sayısı 373 olmalı', rating.ratingCount);

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'Powered by ASUS', 'Marka Powered by ASUS olmalı', brand);
  }

  // 5. Product #4: Thermalright Assassin King 120 SE
  console.log('\n--- 5. Product #4 (Thermalright Soğutucu) ---');
  const htmlPath4 = path.join(__dirname, '../../scratch/gaming_gen_4.html');
  if (fs.existsSync(htmlPath4)) {
    const html = fs.readFileSync(htmlPath4, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title && title.includes('Thermalright Assassin King'), 'Başlık Thermalright içermeli', title);

    const price = scraper.scrapePrice($, html);
    assert(price === 1999.00, 'Satış fiyatı 1.999,00 TL olmalı', price);

    const rating = scraper.scrapeRating($);
    assert(rating.ratingValue === 4.9, 'Rating 4.9 olmalı', rating.ratingValue);
    assert(rating.ratingCount === 79, 'Değerlendirme sayısı 79 olmalı', rating.ratingCount);

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'Thermalright', 'Marka Thermalright olmalı', brand);

    const bc = scraper.scrapeBreadcrumbs($, html);
    assert(bc.includes('Hava Soğutma'), 'Kategori kırıntısı Hava Soğutma içermeli', JSON.stringify(bc));
  }

  // 6. Product #5: GameRaider IGNIA GR16 Gaming Laptop
  console.log('\n--- 6. Product #5 (GameRaider Gaming Laptop) ---');
  const htmlPath5 = path.join(__dirname, '../../scratch/gaming_gen_5.html');
  if (fs.existsSync(htmlPath5)) {
    const html = fs.readFileSync(htmlPath5, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title && title.includes('GameRaider IGNIA GR16'), 'Başlık GameRaider içermeli', title);

    const price = scraper.scrapePrice($, html);
    assert(price === 99999.00, 'Satış fiyatı 99.999,00 TL olmalı', price);

    const rating = scraper.scrapeRating($);
    assert(rating.ratingValue === 5.0, 'Rating 5.0 olmalı', rating.ratingValue);
    assert(rating.ratingCount === 10, 'Değerlendirme sayısı 10 olmalı', rating.ratingCount);

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'GameRaider', 'Marka GameRaider olmalı', brand);

    const bc = scraper.scrapeBreadcrumbs($, html);
    assert(bc.includes('Gaming Laptop'), 'Kategori kırıntısı Gaming Laptop içermeli', JSON.stringify(bc));
  }

  // 7. Product #6: Cybeart Oyuncu Koltuğu (Değerlendirme Yok)
  console.log('\n--- 7. Product #6 (Cybeart Koltuk - Değerlendirme Yok) ---');
  const htmlPath6 = path.join(__dirname, '../../scratch/gaming_gen_6.html');
  if (fs.existsSync(htmlPath6)) {
    const html = fs.readFileSync(htmlPath6, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title && title.includes('Cybeart Apex Series'), 'Başlık Cybeart içermeli', title);

    const price = scraper.scrapePrice($, html);
    assert(price === 14999.00, 'Satış fiyatı 14.999,00 TL olmalı', price);

    const rating = scraper.scrapeRating($);
    assert(rating.ratingValue === null && rating.ratingCount === null, 'Değerlendirme null olmalı', JSON.stringify(rating));

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'Cybeart', 'Marka Cybeart olmalı', brand);
  }

  // 8. Product #7: MSI All In One Bilgisayar (Değerlendirme Yok)
  console.log('\n--- 8. Product #7 (MSI AIO PC - Değerlendirme Yok) ---');
  const htmlPath7 = path.join(__dirname, '../../scratch/gaming_gen_7.html');
  if (fs.existsSync(htmlPath7)) {
    const html = fs.readFileSync(htmlPath7, 'utf-8');
    const $ = cheerio.load(html);

    const title = scraper.scrapeTitle($);
    assert(title && title.includes('MSI PRO AP272P'), 'Başlık MSI PRO AP272P içermeli', title);

    const price = scraper.scrapePrice($, html);
    assert(price === 61899.00, 'Satış fiyatı 61.899,00 TL olmalı', price);

    const rating = scraper.scrapeRating($);
    assert(rating.ratingValue === null && rating.ratingCount === null, 'Değerlendirme null olmalı', JSON.stringify(rating));

    const brand = scraper.scrapeBrand($, html);
    assert(brand === 'MSI', 'Marka MSI olmalı', brand);
  }

  console.log(`\n========================================`);
  console.log(`TEST SONUCU: ${passed}/${total} BAŞARILI (${failed} HATA)`);
  console.log(`========================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
