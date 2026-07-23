const assert = require('assert');
const cheerio = require('cheerio');
const DefactoScraper = require('../scrapers/defacto_scraper');

async function run() {
  const scraper = new DefactoScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.defacto.com.tr/regular-fit-mavi-pamuklu-jean-bermuda-sort-3401791'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. JSON-LD with comma-separated ratingValue and plain string brand
  const html = `
    <script type="application/ld+json">{"@context":"https://schema.org/","@type":"Product","name":"Regular Fit Pamuklu Jean Bermuda Şort","brand":"DeFacto","offers":{"@type":"Offer","price":"999.99","priceCurrency":"TRY"},"aggregateRating":{"@type":"AggregateRating","ratingValue":"5,00","bestRating":"5.0","worstRating":"1.0","ratingCount":"1","reviewCount":"1"}}</script>
  `;
  const $ = cheerio.load(html);
  const rating = await scraper.scrapeRating($);
  assert.strictEqual(rating.ratingValue, 5.0, 'ratingValue should be 5.0 (from "5,00")');
  assert.strictEqual(rating.ratingCount, 1, 'ratingCount should be 1');
  assert.strictEqual(scraper.scrapeBrand($), 'DeFacto', 'brand should be plain string DeFacto');
}

module.exports = { run };
