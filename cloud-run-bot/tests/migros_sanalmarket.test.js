const assert = require('assert');
const cheerio = require('cheerio');
const MigrosScraper = require('../scrapers/migros_scraper');
const { scrapeProductFromUrl } = require('../link_scraper_service');

async function testMigrosSanalmarket() {
  console.log('🧪 Testing Migros Sanalmarket & Marketplace (Node.js)...');
  const scraper = new MigrosScraper();

  // Test 1: ID extraction (including query params, hash and trailing slash)
  assert.strictEqual(scraper.extractProductId(null, 'https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1'), '5010401');
  assert.strictEqual(scraper.extractProductId(null, 'https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1?recom=1&page=2'), '5010401');
  assert.strictEqual(scraper.extractProductId(null, 'https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1/'), '5010401');
  assert.strictEqual(scraper.extractProductId(null, 'https://www.migros.com.tr/grocery-mp/ugg-1116109-mnl-classic-ultra-mini-kadin-bot-bej-36-p-3150731'), '51709745');
  assert.strictEqual(scraper.extractProductId(null, 'https://www.migros.com.tr/hemen/nestle-beyaz-kare-cikolata-60-g-p-6b6158#reviews'), '7037272');
  console.log('✅ Test 1: extractProductId passed!');

  // Test 2: Slug Title Parsing
  assert.strictEqual(scraper.parseSlugTitle('https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1'), 'Söke Un 1 Kg');
  assert.strictEqual(scraper.parseSlugTitle('https://www.migros.com.tr/grocery-mp/organik-sut-1-l-p-abcdef'), 'Organik Süt 1 L');
  console.log('✅ Test 2: parseSlugTitle passed!');

  // Test 3: Söke Un Scrape
  const sokeUrl = 'https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1';
  const sokeHtml = `
    <html>
      <head>
        <title>Migros</title>
        <meta property="og:title" content="Migros">
        <meta property="og:image" content="https://images.migrosone.com/sanalmarket/custom/sanalmarket-seo-34706362.png">
        <link rel="canonical" href="${sokeUrl}">
      </head>
      <body></body>
    </html>
  `;
  const $soke = cheerio.load(sokeHtml);
  await scraper.prepare($soke, sokeUrl);

  const sokeTitle = scraper.scrapeTitle($soke);
  assert(sokeTitle && sokeTitle.includes('Söke Un'), `Expected Söke Un in title, got: ${sokeTitle}`);

  const sokeImage = scraper.scrapeImage($soke, sokeUrl);
  assert(sokeImage && !sokeImage.includes('sanalmarket-seo'), `Image should not be banner, got: ${sokeImage}`);
  assert(sokeImage.includes('images.migrosone.com/sanalmarket/product'), `Image should be product image, got: ${sokeImage}`);

  const sokePrice = await scraper.scrapePrice($soke, sokeUrl);
  assert(sokePrice && sokePrice > 0, `Price should be positive, got: ${sokePrice}`);

  const sokeOrigPrice = await scraper.scrapeOriginalPrice($soke, sokePrice, sokeUrl);
  assert(sokeOrigPrice && sokeOrigPrice > sokePrice, `Original price should be greater than current price`);

  const sokeLabel = await scraper.scrapePriceLabel($soke);
  assert.strictEqual(sokeLabel, 'Money ile');

  const sokeBrand = scraper.scrapeBrand($soke);
  assert.strictEqual(sokeBrand, 'Söke');
  console.log('✅ Test 3: Söke Un scraper passed!');

  // Test 4: WeakMap Concurrency Isolation
  console.log('Testing WeakMap concurrency isolation between two products...');
  const uggUrl = 'https://www.migros.com.tr/grocery-mp/ugg-1116109-mnl-classic-ultra-mini-kadin-bot-bej-36-p-3150731';
  const $doc1 = cheerio.load('<html><head><title>Migros</title></head><body></body></html>');
  const $doc2 = cheerio.load('<html><head><title>Migros</title></head><body></body></html>');

  // Interleaved prepare
  await scraper.prepare($doc1, sokeUrl);
  await scraper.prepare($doc2, uggUrl);

  // $doc1 should return Söke Un
  const title1 = scraper.scrapeTitle($doc1);
  const price1 = await scraper.scrapePrice($doc1);
  assert(title1.includes('Söke Un'), `doc1 title mismatch: ${title1}`);
  assert(price1 < 200, `doc1 price mismatch: ${price1}`);

  // $doc2 should return UGG Bot with Money promotion
  const title2 = scraper.scrapeTitle($doc2);
  const price2 = await scraper.scrapePrice($doc2, uggUrl);
  const origPrice2 = await scraper.scrapeOriginalPrice($doc2, price2, uggUrl);
  const label2 = await scraper.scrapePriceLabel($doc2);
  assert(title2.toLowerCase().includes('ugg'), `doc2 title mismatch: ${title2}`);
  assert.strictEqual(price2, 11999.95, `doc2 price should be 11999.95, got: ${price2}`);
  assert.strictEqual(origPrice2, 13999.95, `doc2 origPrice should be 13999.95, got: ${origPrice2}`);
  assert.strictEqual(label2, 'Money ile', `doc2 priceLabel should be 'Money ile', got: ${label2}`);
  console.log('✅ Test 4: WeakMap concurrency isolation & UGG Money discount passed!');

  // Test 5: End-to-end scrapeProductFromUrl for Söke Un
  console.log('Testing scrapeProductFromUrl end-to-end for Söke Un...');
  const res = await scrapeProductFromUrl(sokeUrl);
  assert(res, 'Result should not be null');
  assert(res.title && res.title.includes('Söke Un'), `Title mismatch: ${res.title}`);
  assert(res.imageUrl && !res.imageUrl.includes('sanalmarket-seo'), `Image should not be placeholder banner`);
  assert(res.price && res.price > 0, `Price mismatch: ${res.price}`);
  assert(res.originalPrice && res.originalPrice > res.price, `Original price mismatch: ${res.originalPrice}`);
  assert.strictEqual(res.brand, 'Söke');
  assert.strictEqual(res.priceLabel, 'Money ile');
  console.log('✅ Test 5: scrapeMetadata end-to-end passed for Söke Un!');

  // Test 6: End-to-end scrapeProductFromUrl for UGG Bot & Gepettoys
  console.log('Testing scrapeProductFromUrl end-to-end for UGG Bot & Gepettoys...');
  const resUgg = await scrapeProductFromUrl(uggUrl);
  assert(resUgg, 'UGG result should not be null');
  assert.strictEqual(resUgg.price, 11999.95, `UGG price mismatch: ${resUgg.price}`);
  assert.strictEqual(resUgg.originalPrice, 13999.95, `UGG originalPrice mismatch: ${resUgg.originalPrice}`);
  assert.strictEqual(resUgg.priceLabel, 'Money ile', `UGG priceLabel mismatch: ${resUgg.priceLabel}`);
  assert.strictEqual(resUgg.brand, 'Ugg');

  const gepettoysUrl = 'https://www.migros.com.tr/grocery-mp/gepettoys-catch-ball-set-18-cm-p-229439a';
  const resGepettoys = await scrapeProductFromUrl(gepettoysUrl);
  assert(resGepettoys, 'Gepettoys result should not be null');
  assert.strictEqual(resGepettoys.price, 71.97, `Gepettoys price mismatch: ${resGepettoys.price}`);
  assert.strictEqual(resGepettoys.originalPrice, 119.95, `Gepettoys originalPrice mismatch: ${resGepettoys.originalPrice}`);
  assert.strictEqual(resGepettoys.priceLabel, 'Money ile', `Gepettoys priceLabel mismatch: ${resGepettoys.priceLabel}`);
  console.log('✅ Test 6: scrapeMetadata end-to-end passed for UGG Bot and Gepettoys!');

  console.log('\n🎉 ALL MIGROS SANALMARKET TESTS PASSED!');
}

testMigrosSanalmarket().catch(err => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
