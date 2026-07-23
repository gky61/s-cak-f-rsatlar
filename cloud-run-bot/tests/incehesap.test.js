const assert = require('assert');
const cheerio = require('cheerio');
const IncehesapScraper = require('../scrapers/incehesap_scraper');

async function run() {
  const scraper = new IncehesapScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.incehesap.com/james-donkey-jd450-gaming-mouse-fiyati-3087770/'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. DOM microdata for rating and brand
  const html = `
    <div itemprop="aggregateRating" itemscope="" itemtype="https://schema.org/AggregateRating">
      Rated <span itemprop="ratingValue">5</span>/5
      based on <span itemprop="reviewCount">2</span> customer reviews
    </div>
    <div itemprop="brand" itemtype="https://schema.org/Brand" itemscope="">
      <meta itemprop="name" content="James Donkey">
    </div>
  `;
  const $ = cheerio.load(html);
  const rating = await scraper.scrapeRating($);
  assert.strictEqual(rating.ratingValue, 5, 'ratingValue should be 5');
  assert.strictEqual(rating.ratingCount, 2, 'ratingCount should be 2');
  assert.strictEqual(scraper.scrapeBrand($), 'James Donkey', 'brand should be James Donkey from itemprop');
}

module.exports = { run };
