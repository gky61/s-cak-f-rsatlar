const assert = require('assert');
const cheerio = require('cheerio');
const TrendyolScraper = require('../scrapers/trendyol_scraper');

function run() {
  const scraper = new TrendyolScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.trendyol.com/robeve/550-ml-p-898167691'), true);
  assert.strictEqual(scraper.canHandle('https://ty.gl/some-short-url'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. JSON-LD parsing
  const html = `
    <script type="application/ld+json">{
      "@context": "https://schema.org",
      "@type": "ProductGroup",
      "name": "ROBEVE 550 ml Otomatik Hava Nemlendirici Buhar Makinesi Oda Nemlendirici Aroma Difüzör Beyaz",
      "image": {
        "type": "ImageObject",
        "contentUrl": [
          "https://cdn.dsmcdn.com/ty1783/prod/QC_ENRICHMENT/20251103/21/e1fbb2d1-553b-3dec-af2f-076c33520c1c/1_org_zoom.jpg"
        ]
      },
      "offers": {
        "@type": "Offer",
        "price": "486.67"
      }
    }</script>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'ROBEVE 550 ml Otomatik Hava Nemlendirici Buhar Makinesi Oda Nemlendirici Aroma Difüzör Beyaz');
  assert.strictEqual(scraper.scrapePrice($), 486.67);
  assert.strictEqual(scraper.scrapeImage($, 'https://www.trendyol.com/some-product'), 'https://cdn.dsmcdn.com/ty1783/prod/QC_ENRICHMENT/20251103/21/e1fbb2d1-553b-3dec-af2f-076c33520c1c/1_org_zoom.jpg');

  // 3. Trendyol ld+json rating and brand
  const html2 = `
    <script type="application/ld+json">{
     "@context": "https://schema.org",
     "@type": "Product",
     "name": "KTC H27T22C 27″ 1Ms(GtG) 200Hz (210Hz O.C.) 2K QHD Fast IPS Gaming Monitör",
     "brand": {
      "@type": "Brand",
      "name": "KTC"
     },
     "offers": {
      "@type": "Offer",
      "price": "7899.00"
     },
     "aggregateRating": {
      "@type": "AggregateRating",
      "ratingValue": 4.5,
      "ratingCount": 33,
      "reviewCount": 21
     }
    }</script>
  `;
  const $2 = cheerio.load(html2);
  assert.strictEqual(scraper.scrapeTitle($2), 'KTC H27T22C 27″ 1Ms(GtG) 200Hz (210Hz O.C.) 2K QHD Fast IPS Gaming Monitör');
  assert.strictEqual(scraper.scrapePrice($2), 7899.00);
  const rating2 = scraper.scrapeRating($2);
  assert.strictEqual(rating2.ratingValue, 4.5);
  assert.strictEqual(rating2.ratingCount, 33);
  assert.strictEqual(scraper.scrapeBrand($2), 'KTC');

  // 4. priceLabel Tests (False Positive Prevention vs True Plus)
  const htmlFalse = `
    <!DOCTYPE html>
    <html>
    <head>
      <script>window["__envoy_ty-plus-banner__CONDITION"]=false</script>
      <script>function tyPlusHelper() { return "ty-plus plusPromotion isPlusExclusive"; }</script>
    </head>
    <body>
      <div>Normal Ürün Başlığı</div>
      <span>299 TL</span>
    </body>
    </html>
  `;
  const $false = cheerio.load(htmlFalse);
  assert.strictEqual(scraper.scrapePriceLabel($false), null, 'ty-plus genel bundle kodları Plus olarak algılanmamalıdır!');

  const htmlTrueDom = `
    <div>
      <div class="ty-plus-price-header">Trendyol Plus'a Özel</div>
      <span class="ty-plus-price-discounted-price">178,64 TL</span>
    </div>
  `;
  const $trueDom = cheerio.load(htmlTrueDom);
  assert.strictEqual(scraper.scrapePriceLabel($trueDom), "Plus'a Özel", 'DOM Plus fiyatı algılanmalı');

  const htmlTrueScript = `
    <script>window["__envoy_ty-plus-banner__CONDITION"]=true</script>
  `;
  const $trueScript = cheerio.load(htmlTrueScript);
  assert.strictEqual(scraper.scrapePriceLabel($trueScript), "Plus'a Özel", 'Script condition=true algılanmalı');
}

module.exports = { run };
