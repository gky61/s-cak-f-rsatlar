const assert = require('assert');
const cheerio = require('cheerio');
const PttavmScraper = require('../scrapers/pttavm_scraper');

async function run() {
  const scraper = new PttavmScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.pttavm.com/dijitsu-db120rre-retro-kirmizi-mini-buzdolabi-p-1458599324'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. JSON-LD with numeric ratingValue and additionalProperty brand
  const html = `
    <script type="application/ld+json">{"@context":"https://schema.org","@type":"Product","name":"Dijitsu DB120RRE Retro Kırmızı Mini Buzdolabı","brand":{"@type":"Brand","name":"FIRSATLARALEMİ"},"offers":{"@type":"Offer","price":6699,"priceCurrency":"TRY"},"aggregateRating":{"@type":"AggregateRating","ratingValue":1.8,"reviewCount":5,"bestRating":5,"worstRating":1},"additionalProperty":[{"@type":"PropertyValue","name":"External Source","value":"Dijitsu"},{"@type":"PropertyValue","name":"External ID","value":"Dijitsu DB120RRE"}]}</script>
  `;
  const $ = cheerio.load(html);
  const rating = await scraper.scrapeRating($);
  assert.strictEqual(rating.ratingValue, 1.8, 'ratingValue should be 1.8');
  assert.strictEqual(rating.ratingCount, 5, 'ratingCount should be 5');
  // Brand: additionalProperty "External Source" -> "Dijitsu" (not seller "FIRSATLARALEMİ")
  assert.strictEqual(scraper.scrapeBrand($), 'Dijitsu', 'brand should be Dijitsu from additionalProperty');
}

module.exports = { run };
