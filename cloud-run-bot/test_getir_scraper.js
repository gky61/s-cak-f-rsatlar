const fs = require('fs');
const cheerio = require('cheerio');
const GetirScraper = require('./scrapers/getir_scraper');

function runTests() {
  console.log('🧪 Running Node.js GetirScraper Unit Tests...');

  const scraper = new GetirScraper();

  // Test canHandle
  const canHandle1 = scraper.canHandle('https://getir.com/urun/chunkies-magnum-badem-nogger-paketi-mkbemgrdz5/');
  const canHandle2 = scraper.canHandle('https://www.google.com');

  console.log(`canHandle(Getir URL): ${canHandle1 ? 'PASS' : 'FAIL'}`);
  console.log(`canHandle(Google URL): ${!canHandle2 ? 'PASS' : 'FAIL'}`);

  if (!canHandle1 || canHandle2) {
    console.error('❌ canHandle test failed!');
    process.exit(1);
  }

  // Load local HTML
  const html = fs.readFileSync('scratch/getir_page_utf8.html', 'utf8');
  const $ = cheerio.load(html);

  // Test scrapeTitle
  const title = scraper.scrapeTitle($);
  console.log(`scrapeTitle: "${title}"`);
  if (title !== 'Chunkies & Magnum Badem & Nogger Paketi') {
    console.error('❌ scrapeTitle test failed!');
    process.exit(1);
  }

  // Test scrapePrice
  const price = scraper.scrapePrice($);
  console.log(`scrapePrice: ${price} TL`);
  if (price !== 367.99) {
    console.error('❌ scrapePrice test failed!');
    process.exit(1);
  }

  // Test scrapeDescription
  const desc = scraper.scrapeDescription($);
  console.log(`scrapeDescription: "${desc}"`);
  if (desc !== '3 Adet') {
    console.error('❌ scrapeDescription test failed!');
    process.exit(1);
  }

  // Test scrapeImage
  const url = 'https://getir.com/urun/chunkies-magnum-badem-nogger-paketi-mkbemgrdz5/';
  const image = scraper.scrapeImage($, url);
  console.log(`scrapeImage: "${image}"`);
  if (image !== 'https://cdn-image.getir.com/market/product/48c81d77-9f2e-48d2-905c-6d49668ab0d5.jpg') {
    console.error('❌ scrapeImage test failed!');
    process.exit(1);
  }

  console.log('✅ ALL NODE.JS GETIR SCRAPER TESTS PASSED!');
}

runTests();
