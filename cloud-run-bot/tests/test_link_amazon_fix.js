const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

async function run() {
  const shortUrl = 'https://link.amazon/B09J6uXeZ';
  console.log('Testing scrapeProductFromUrl for short link:', shortUrl);

  const result = await linkScraperService.scrapeProductFromUrl(shortUrl);
  console.log('Scraped Title:', result.title);
  console.log('Scraped Price:', result.price);
  console.log('Scraped Brand:', result.brand);
  console.log('Scraped Rating:', result.ratingValue, '(', result.ratingCount, 'oy)');

  assert.ok(result.title && result.title.includes('Belkin'), 'Title should contain Belkin');
  assert.strictEqual(result.price, 349, 'Price should be 349');
  assert.strictEqual(result.brand, 'Belkin', 'Brand should be Belkin');
  assert.strictEqual(result.ratingValue, 4.7, 'RatingValue should be 4.7');
  assert.ok(result.ratingCount > 0, 'RatingCount should be > 0');

  console.log('✅ link.amazon short link test PASSED!');
}

run();
