const assert = require('assert');
const cheerio = require('cheerio');
const DefactoScraper = require('../scrapers/defacto_scraper');

function run() {
  const scraper = new DefactoScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.defacto.com.tr/fitted-gomlek-3152656'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. normal price, title, description, image
  const html1 = `
    <head>
      <meta property="og:image" content="https://dfcdn.net/mnresize/800/-/product/V7699AZ_26SP_WT32_01_04.jpg">
      <meta name="description" content="NEW REGULAR FIT Basic Tişört en iyi fiyatla DeFacto'da.">
    </head>
    <body>
      <script>
        window.PRODUCT_DETAIL_LASTVISITED={
          ProductVariantMiniDiscountedPriceInclTax:"299.99",
          ProductVariantMiniProductName:"%100 Pamuk NEW REGULAR FIT Basic Ti&#x15F;&#xF6;rt"
        };
      </script>
    </body>
  `;
  const $1 = cheerio.load(html1);

  assert.strictEqual(scraper.scrapePrice($1), 299.99);
  assert.strictEqual(scraper.scrapeTitle($1), '%100 Pamuk NEW REGULAR FIT Basic Tişört');
  assert.strictEqual(scraper.scrapeDescription($1), "NEW REGULAR FIT Basic Tişört en iyi fiyatla DeFacto'da.");
  assert.strictEqual(scraper.scrapeImage($1, 'https://www.defacto.com.tr/fitted-gomlek-3152656'), 'https://dfcdn.net/mnresize/800/-/product/V7699AZ_26SP_WT32_01_04.jpg');

  // 3. campaign price
  const html2 = `
    <body>
      <script>
        window.PRODUCT_DETAIL_LASTVISITED={
          ProductVariantMiniDiscountedPriceInclTax:"799.99",
          ProductVariantMiniProductName:"Fitted K&#x131;r&#x131;&#x15F;&#x131;k Dokulu Kuma&#x15F; G&#xF6;mlek",
          CampaignBadge:{"CampaignId":"30082587-eba3-4047-b7cd-3de4f24e7a2d","DiscountPrice":399.99}
        };
      </script>
    </body>
  `;
  const $2 = cheerio.load(html2);
  assert.strictEqual(scraper.scrapePrice($2), 399.99);
  assert.strictEqual(scraper.scrapeTitle($2), 'Fitted Kırışık Dokulu Kumaş Gömlek');
}

module.exports = { run };
