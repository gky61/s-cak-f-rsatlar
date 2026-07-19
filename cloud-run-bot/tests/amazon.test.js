const assert = require('assert');
const cheerio = require('cheerio');
const AmazonScraper = require('../scrapers/amazon_scraper');

function run() {
  const scraper = new AmazonScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.amazon.com.tr/dp/B0CFYNMDF2'), true);
  assert.strictEqual(scraper.canHandle('https://amzn.to/some-short-url'), true);
  assert.strictEqual(scraper.canHandle('https://link.amazon/B0aH5993k'), true);
  assert.strictEqual(scraper.canHandle('https://amzlinks.in/B0aH5993k'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. Normal Amazon page (JSON-LD offers, description meta, title element)
  const html = `
    <head>
      <title>Apple 2024 MacBook Air 13.6 inç M3 çip 8GB RAM 256GB SSD</title>
      <meta name="description" content="M3 çipli MacBook Air dizüstü bilgisayar.">
    </head>
    <body>
      <span id="productTitle">Apple 2024 MacBook Air 13.6 inç M3 çip 8GB RAM 256GB SSD</span>
      <div id="wayfinding-breadcrumbs_feature_div">
        <ul class="a-unordered-list a-horizontal">
          <li><span class="a-list-item"><a class="a-link-normal" href="#">Elektronik</a></span></li>
          <li><span class="a-list-item"><a class="a-link-normal" href="#">Bilgisayar</a></span></li>
        </ul>
      </div>
      <div id="landingImage" data-a-dynamic-image='{"https://m.media-amazon.com/images/I/71-D7S3k7AL._AC_SL1500_.jpg":[1500,1500]}'></div>
      <span class="a-price a-text-price a-size-medium apexPriceToPay">
        <span class="a-offscreen">39.999,00TL</span>
      </span>
    </body>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'Apple 2024 MacBook Air 13.6 inç M3 çip 8GB RAM 256GB SSD');
  assert.strictEqual(scraper.scrapePrice($), 39999.0);
  assert.strictEqual(scraper.scrapeDescription($), 'M3 çipli MacBook Air dizüstü bilgisayar.');
  assert.strictEqual(scraper.scrapeImage($, 'https://www.amazon.com.tr/dp/B0CFYNMDF2'), 'https://m.media-amazon.com/images/I/71-D7S3k7AL._AC_SL1500_.jpg');
  assert.deepStrictEqual(scraper.scrapeBreadcrumbs($), ['Elektronik', 'Bilgisayar']);
}

module.exports = { run };
