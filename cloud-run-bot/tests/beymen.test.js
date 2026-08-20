const assert = require('assert');
const cheerio = require('cheerio');
const BeymenScraper = require('../scrapers/beymen_scraper');

function run() {
  const scraper = new BeymenScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.beymen.com/tr/p_etro-lacivert-etnik-desenli-gomlek_1627505'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. normal price, title, image, description
  const html = `
    <script type="application/ld+json">
    {
        "@context": "https://schema.org/",
        "@type": "Product",
        "name": "Lacivert Etnik Desenli Gömlek",
        "image": [
            "https://cdn.beymen.com/productimages/aj4ffhsd.rcf_IMG_01_2110099740461.jpg"
        ],
        "description": "Düğmeli yaka, etnik desenli gömlek.",
        "offers": {
            "@type": "Offer",
            "price": "30450.00"
        }
    }
    </script>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'Lacivert Etnik Desenli Gömlek');
  assert.strictEqual(scraper.scrapePrice($), 30450.0);
  assert.strictEqual(scraper.scrapeDescription($), 'Düğmeli yaka, etnik desenli gömlek.');
  assert.strictEqual(scraper.scrapeImage($, 'https://www.beymen.com/tr/p_etro-lacivert-etnik-desenli-gomlek_1627505'), 'https://cdn.beymen.com/productimages/aj4ffhsd.rcf_IMG_01_2110099740461.jpg');

  // 3. Multi-discount with m-price__lastPrice (Dolce & Gabbana 70.950 -> 51.995 -> 44.195)
  const multiDiscountHtml = `
    <div class="m-price">
      <div class="m-price__list">
        <del id="priceOld" class="m-price__old">70.950 TL</del>
        <ins id="priceNew" class="m-price__new -discnt">51.995 TL</ins>
      </div>
      <div class="m-price__lastPrice">
        44.195 TL
      </div>
    </div>
  `;
  const $multi = cheerio.load(multiDiscountHtml);
  const multiPrice = scraper.scrapePrice($multi);
  assert.strictEqual(multiPrice, 44195.0);
  assert.strictEqual(scraper.scrapeOriginalPrice($multi, multiPrice), 70950.0);

  // 4. Multi-discount with campaignPrice (AMI Paris 27.450 -> 14.495 -> 13.195 -> 10.556)
  const campaignHtml = `
    <div class="m-price">
      <div class="m-price__list">
        <del id="priceOld" class="m-price__old">27.450 TL</del>
        <ins id="priceNew" class="m-price__new -discnt">14.495 TL</ins>
      </div>
      <div class="m-price__lastPrice">
        13.195 TL
      </div>
      <div class="m-price__campaign">
        <span class="m-price__campaignPrice">
          10.556 TL
        </span>
      </div>
    </div>
  `;
  const $camp = cheerio.load(campaignHtml);
  const campPrice = scraper.scrapePrice($camp);
  assert.strictEqual(campPrice, 10556.0);
  assert.strictEqual(scraper.scrapeOriginalPrice($camp, campPrice), 27450.0);
}

module.exports = { run };
