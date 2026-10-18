const assert = require('assert');
const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');
const CarrefoursaScraper = require('../scrapers/carrefoursa_scraper');
const affiliateManager = require('../affiliate_manager');

async function runCarrefoursaTests() {
  console.log('🧪 Starting CarrefourSA Scraper Tests (Node.js)...\n');
  const scraper = new CarrefoursaScraper();

  // Test 1: canHandle validation
  assert.strictEqual(scraper.canHandle('https://www.carrefoursa.com/heinz-tatli-ketcap-570-g-p-30455671'), true);
  assert.strictEqual(scraper.canHandle('https://carrefoursa.com/dana-kiyma-p-30054577'), true);
  assert.strictEqual(scraper.canHandle('https://www.migros.com.tr/product-p-123'), false);
  assert.strictEqual(scraper.canHandle('https://www.trendyol.com/item-p-456'), false);
  console.log('✅ Test 1: canHandle validation passed!');

  const fixturesDir = path.join(__dirname, 'fixtures', 'carrefoursa');

  // Test 2: Product #1 - Heinz Tatlı Ketçap 570 g
  // Beklenen: İndirimsiz 169,95 TL, CarrefourSA Kart ile 127,46 TL
  const p0Html = fs.readFileSync(path.join(fixturesDir, 'sample_0.html'), 'utf-8');
  const $0 = cheerio.load(p0Html);
  const p0Url = 'https://www.carrefoursa.com/heinz-tatli-ketcap-570-g-p-30455671';

  const title0 = scraper.scrapeTitle($0);
  assert(title0 && title0.includes('Heinz Tatlı Ketçap 570 g'), `Expected Heinz title, got: ${title0}`);

  const brand0 = scraper.scrapeBrand($0);
  assert.strictEqual(brand0, 'HEINZ');

  const price0 = scraper.scrapePrice($0);
  assert.strictEqual(price0, 127.46, `Expected price 127.46, got: ${price0}`);

  const origPrice0 = scraper.scrapeOriginalPrice($0, price0);
  assert.strictEqual(origPrice0, 169.95, `Expected originalPrice 169.95, got: ${origPrice0}`);

  const label0 = scraper.scrapePriceLabel($0);
  assert.strictEqual(label0, 'CarrefourSA Kart ile', `Expected label 'CarrefourSA Kart ile', got: ${label0}`);

  const image0 = scraper.scrapeImage($0, p0Url);
  assert(image0 && image0.includes('images.csfour.com'), `Expected csfour image, got: ${image0}`);

  const breadcrumbs0 = scraper.scrapeBreadcrumbs($0);
  assert.deepStrictEqual(breadcrumbs0, ['Temel Gıda', 'Soslar', 'Ketçap']);
  console.log('✅ Test 2: Product #1 (Heinz Ketçap) passed: 127,46 TL / 169,95 TL [CarrefourSA Kart ile]');

  // Test 3: Product #2 - Smile Bentonit Kedi Kumu Natural 5 L
  // Beklenen: 129,50 TL, CarrefourSA Kart ile 2 Al 1 Öde
  const p1Html = fs.readFileSync(path.join(fixturesDir, 'sample_1.html'), 'utf-8');
  const $1 = cheerio.load(p1Html);
  const p1Url = 'https://www.carrefoursa.com/smile-bentonit-kedi-kumu-natural-5-l-p-30498020';

  const title1 = scraper.scrapeTitle($1);
  assert(title1 && title1.includes('Smile Bentonit Kedi Kumu Natural 5 L'), `Expected Smile title, got: ${title1}`);

  const brand1 = scraper.scrapeBrand($1);
  assert.strictEqual(brand1, 'SMİLE');

  const price1 = scraper.scrapePrice($1);
  assert.strictEqual(price1, 129.5, `Expected price 129.5, got: ${price1}`);

  const origPrice1 = scraper.scrapeOriginalPrice($1, price1);
  assert.strictEqual(origPrice1, null, `Expected originalPrice null, got: ${origPrice1}`);

  const label1 = scraper.scrapePriceLabel($1);
  assert.strictEqual(label1, 'CarrefourSA Kart ile 2 Al 1 Öde', `Expected label 'CarrefourSA Kart ile 2 Al 1 Öde', got: ${label1}`);

  const image1 = scraper.scrapeImage($1, p1Url);
  assert(image1 && image1.includes('images.csfour.com'), `Expected csfour image, got: ${image1}`);

  const breadcrumbs1 = scraper.scrapeBreadcrumbs($1);
  assert.deepStrictEqual(breadcrumbs1, ['Pet Shop', 'Kedi', 'Kedi Kumu']);
  console.log('✅ Test 3: Product #2 (Kedi Kumu) passed: 129,50 TL [CarrefourSA Kart ile 2 Al 1 Öde]');

  // Test 4: Product #3 - Dana Kıyma (%14-%20 Yağ) kg
  // Beklenen: İndirimsiz 879,90 TL, CarrefourSA Kart ile 749,90 TL
  const p2Html = fs.readFileSync(path.join(fixturesDir, 'sample_2.html'), 'utf-8');
  const $2 = cheerio.load(p2Html);
  const p2Url = 'https://www.carrefoursa.com/dana-kiyma-14-20-yag-kg-p-30054577';

  const title2 = scraper.scrapeTitle($2);
  assert(title2 && title2.includes('Dana Kıyma'), `Expected Dana Kıyma title, got: ${title2}`);

  const price2 = scraper.scrapePrice($2);
  assert.strictEqual(price2, 749.9, `Expected price 749.9, got: ${price2}`);

  const origPrice2 = scraper.scrapeOriginalPrice($2, price2);
  assert.strictEqual(origPrice2, 879.9, `Expected originalPrice 879.9, got: ${origPrice2}`);

  const label2 = scraper.scrapePriceLabel($2);
  assert.strictEqual(label2, 'CarrefourSA Kart ile', `Expected label 'CarrefourSA Kart ile', got: ${label2}`);

  const image2 = scraper.scrapeImage($2, p2Url);
  assert(image2 && image2.includes('images.csfour.com'), `Expected csfour image, got: ${image2}`);

  const breadcrumbs2 = scraper.scrapeBreadcrumbs($2);
  assert.deepStrictEqual(breadcrumbs2, ['Et, Tavuk, Balık', 'Kırmızı Et', 'Dana']);
  console.log('✅ Test 4: Product #3 (Dana Kıyma) passed: 749,90 TL / 879,90 TL [CarrefourSA Kart ile]');

  // Test 5: Product #4 - Yudum Ayçiçek Yağı 5 L
  // Beklenen: Tek Fiyat 599,95 TL, İndirimsiz: null, Rozet: null
  const p3Html = fs.readFileSync(path.join(fixturesDir, 'sample_3.html'), 'utf-8');
  const $3 = cheerio.load(p3Html);
  const p3Url = 'https://www.carrefoursa.com/yudum-aycicek-yagi-5-l-p-30088639';

  const title3 = scraper.scrapeTitle($3);
  assert(title3 && title3.includes('Yudum Ayçiçek Yağı 5 L'), `Expected Yudum title, got: ${title3}`);

  const brand3 = scraper.scrapeBrand($3);
  assert.strictEqual(brand3, 'YUDUM');

  const price3 = scraper.scrapePrice($3);
  assert.strictEqual(price3, 599.95, `Expected price 599.95, got: ${price3}`);

  const origPrice3 = scraper.scrapeOriginalPrice($3, price3);
  assert.strictEqual(origPrice3, null, `Expected originalPrice null, got: ${origPrice3}`);

  const label3 = scraper.scrapePriceLabel($3);
  assert.strictEqual(label3, null, `Expected label null, got: ${label3}`);

  const image3 = scraper.scrapeImage($3, p3Url);
  assert(image3 && image3.includes('images.csfour.com'), `Expected csfour image, got: ${image3}`);

  const breadcrumbs3 = scraper.scrapeBreadcrumbs($3);
  assert.deepStrictEqual(breadcrumbs3, ['Temel Gıda', 'Sıvı Yağlar', 'Ayçiçek Yağı']);
  console.log('✅ Test 5: Product #4 (Yudum Yağ) passed: 599,95 TL tek fiyat (etiket ve indirimsiz fiyat yok)');

  // Test 6: Product #5 - Çaykur Rize Turist Çay 1 kg
  // Beklenen: Tek Fiyat 339,95 TL, İndirimsiz: null, Rozet: null
  const p4Html = fs.readFileSync(path.join(fixturesDir, 'sample_4.html'), 'utf-8');
  const $4 = cheerio.load(p4Html);
  const p4Url = 'https://www.carrefoursa.com/caykur-rize-turist-cay-1-kg-p-30037044';

  const title4 = scraper.scrapeTitle($4);
  assert(title4 && title4.includes('Çaykur Rize Turist Çay 1 kg'), `Expected Çaykur title, got: ${title4}`);

  const brand4 = scraper.scrapeBrand($4);
  assert.strictEqual(brand4, 'ÇAYKUR');

  const price4 = scraper.scrapePrice($4);
  assert.strictEqual(price4, 339.95, `Expected price 339.95, got: ${price4}`);

  const origPrice4 = scraper.scrapeOriginalPrice($4, price4);
  assert.strictEqual(origPrice4, null, `Expected originalPrice null, got: ${origPrice4}`);

  const label4 = scraper.scrapePriceLabel($4);
  assert.strictEqual(label4, null, `Expected label null, got: ${label4}`);

  const image4 = scraper.scrapeImage($4, p4Url);
  assert(image4 && image4.includes('images.csfour.com'), `Expected csfour image, got: ${image4}`);

  const breadcrumbs4 = scraper.scrapeBreadcrumbs($4);
  assert(breadcrumbs4.includes('İçecekler') && breadcrumbs4.includes('Çay'), `Expected tea breadcrumbs, got: ${JSON.stringify(breadcrumbs4)}`);
  console.log('✅ Test 6: Product #5 (Çaykur Çay) passed: 339,95 TL tek fiyat (etiket ve indirimsiz fiyat yok)');

  // Test 8: Product #6 - Nescafe Xpress (60,00 TL / 80,00 TL [CarrefourSA Kart ile])
  const nescafeHtml = fs.readFileSync(path.join(fixturesDir, 'nescafe.html'), 'utf-8');
  const $nescafe = cheerio.load(nescafeHtml);
  const nescafePrice = scraper.scrapePrice($nescafe);
  assert.strictEqual(nescafePrice, 60.00, `Expected price 60.00, got: ${nescafePrice}`);
  const nescafeOrig = scraper.scrapeOriginalPrice($nescafe, nescafePrice);
  assert.strictEqual(nescafeOrig, 80.00, `Expected originalPrice 80.00, got: ${nescafeOrig}`);
  const nescafeLabel = scraper.scrapePriceLabel($nescafe);
  assert.strictEqual(nescafeLabel, 'CarrefourSA Kart ile', `Expected label 'CarrefourSA Kart ile', got: ${nescafeLabel}`);
  console.log('✅ Test 8: Product #6 (Nescafe Xpress) passed: 60,00 TL / 80,00 TL [CarrefourSA Kart ile]');

  // Test 9: Product #7 - Kızılay Maden Suyu (49,95 TL / 66,70 TL [CarrefourSA Kart ile])
  const kizilayHtml = fs.readFileSync(path.join(fixturesDir, 'kizilay.html'), 'utf-8');
  const $kizilay = cheerio.load(kizilayHtml);
  const kizilayPrice = scraper.scrapePrice($kizilay);
  assert.strictEqual(kizilayPrice, 49.95, `Expected price 49.95, got: ${kizilayPrice}`);
  const kizilayOrig = scraper.scrapeOriginalPrice($kizilay, kizilayPrice);
  assert.strictEqual(kizilayOrig, 66.70, `Expected originalPrice 66.70, got: ${kizilayOrig}`);
  const kizilayLabel = scraper.scrapePriceLabel($kizilay);
  assert.strictEqual(kizilayLabel, 'CarrefourSA Kart ile', `Expected label 'CarrefourSA Kart ile', got: ${kizilayLabel}`);
  console.log('✅ Test 9: Product #7 (Kızılay Maden Suyu) passed: 49,95 TL / 66,70 TL [CarrefourSA Kart ile]');

  console.log('\n🎉 ALL CARREFOURSA TESTS PASSED SUCCESSFULLY! (9/9)');
}

runCarrefoursaTests().catch(err => {
  console.error('\n❌ CarrefourSA test failed:', err);
  process.exit(1);
});
