const assert = require('assert');
const cheerio = require('cheerio');
const N11Scraper = require('../scrapers/n11_scraper');

function run() {
  const scraper = new N11Scraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.n11.com/urun/nivea-gunes-kremi-1234'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. n11 page elements
  const html = `
    <head>
      <meta property="og:title" content="Nivea Sun Koruyucu Güneş Kremi SPF 50">
      <meta property="og:image" content="https://n11cdn.akamaized.net/a1/org/12/34/56/78.jpg">
      <meta name="description" content="Nivea sun hassas ciltler için güneş kremi.">
    </head>
    <body>
      <div class="big-image-wrapper">
        <img src="https://n11cdn.akamaized.net/a1/org/12/34/56/78.jpg">
      </div>
      <ins class="new-price" val="385.90">385,90 TL</ins>
      <div class="breadcrumb-group">
        <li class="breadcrumb-item"><a href="/kozmetik">Kozmetik & Kişisel Bakım</a></li>
        <li class="breadcrumb-item"><a href="/cilt">Cilt Bakımı</a></li>
      </div>
    </body>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'Nivea Sun Koruyucu Güneş Kremi SPF 50');
  assert.strictEqual(scraper.scrapePrice($), 385.90);
  assert.strictEqual(scraper.scrapeDescription($), 'Nivea sun hassas ciltler için güneş kremi.');
  assert.strictEqual(scraper.scrapeImage($, 'https://www.n11.com/urun/nivea-gunes-kremi-1234'), 'https://n11cdn.akamaized.net/a1/org/12/34/56/78.jpg');
  assert.deepStrictEqual(scraper.scrapeBreadcrumbs($), ['Kozmetik & Kişisel Bakım', 'Cilt Bakımı']);
}

module.exports = { run };
