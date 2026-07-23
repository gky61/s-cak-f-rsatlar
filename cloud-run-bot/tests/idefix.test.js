const assert = require('assert');
const cheerio = require('cheerio');
const IdefixScraper = require('../scrapers/idefix_scraper');

async function run() {
  const scraper = new IdefixScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.idefix.com/klimalar-c-123'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. Idefix elements
  const html = `
    <head>
      <meta property="og:image" content="https://www.idefix.com/product.jpg">
      <meta name="description" content="Duvar tipi klima en iyi fiyatla Idefix'te.">
      <script type="application/ld+json">
      {
        "@context": "https://schema.org/",
        "@type": "BreadcrumbList",
        "itemListElement": [
          {"@type": "ListItem", "position": 0, "name": "Ana sayfa", "item": "https://www.idefix.com/"},
          {"@type": "ListItem", "position": 1, "name": "Teknoloji", "item": "https://www.idefix.com/teknoloji-c-23"},
          {"@type": "ListItem", "position": 2, "name": "Klimalar", "item": "https://www.idefix.com/klimalar-c-23"}
        ]
      }
      </script>
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Duvar Tipi Klima",
        "offers": {
          "price": "14500.00"
        }
      }
      </script>
    </head>
    <body>
      <h1>Duvar Tipi Klima</h1>
    </body>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'Duvar Tipi Klima');
  assert.strictEqual(scraper.scrapePrice($), 14500.0);
  assert.strictEqual(scraper.scrapeDescription($), "Duvar tipi klima en iyi fiyatla Idefix'te.");
  assert.strictEqual(scraper.scrapeImage($, 'https://www.idefix.com/klimalar-c-123'), 'https://www.idefix.com/product.jpg');
  assert.deepStrictEqual(scraper.scrapeBreadcrumbs($), ['Teknoloji', 'Klimalar']);

  // 3. Sample 1: Onvo TV (ratingValue: 5, reviewCount: 1, brand: "Onvo")
  const onvoHtml = `
    <script type="application/ld+json">{"@context":"https://schema.org/","@type":"Product","name":"Onvo 65VQ90F3UA 65'' 165 Ekran Uydu Alıcılı 4K Ultra HD Google Smart QLED TV","image":"https://image01.idefix.com/resize/{size}product/17490103/65vq90f3ua-65-165-ekran-uydu-alicili-4k-ultra-hd-google-smart-qled-tv-6a0af4f5324dd.jpg","description":"Onvo 65VQ90F3UA 65'' 165 Ekran Uydu Alıcılı 4K Ultra HD Google Smart QLED TV yorumlarını inceleyin, idefix’e özel indirimli fiyata satın alın.","brand":{"@type":"Organization","name":"Onvo"},"sku":"8682655704117","gtin13":"8682655704117","aggregateRating":{"@type":"AggregateRating","ratingValue":5,"reviewCount":1,"bestRating":5},"offers":{"@type":"Offer","url":"https://www.idefix.com/onvo-65vq90f3ua-65-165-ekran-uydu-alicili-4k-ultra-hd-google-smart-qled-tv-p-17490103","priceCurrency":"TRY","price":26935.09,"priceSpecification":{"@type":"UnitPriceSpecification","priceCurrency":"TRY","price":29599,"priceType":"https://schema.org/ListPrice"},"itemCondition":"https://schema.org/NewCondition","availability":"https://schema.org/InStock"}}</script>
  `;
  const $onvo = cheerio.load(onvoHtml);
  assert.strictEqual(scraper.scrapeTitle($onvo), "Onvo 65VQ90F3UA 65'' 165 Ekran Uydu Alıcılı 4K Ultra HD Google Smart QLED TV");
  assert.strictEqual(scraper.scrapePrice($onvo), 26935.09);
  const ratingOnvo = await scraper.scrapeRating($onvo);
  assert.strictEqual(ratingOnvo.ratingValue, 5);
  assert.strictEqual(ratingOnvo.ratingCount, 1);
  assert.strictEqual(scraper.scrapeBrand($onvo), 'Onvo');

  // 4. Sample 2: LG TV (ratingValue: 4.8, reviewCount: 32, brand: "LG", with raw newlines in reviewBody)
  const lgHtml = `
    <script type="application/ld+json">{"@context":"https://schema.org/","@type":"Product","name":"LG  65QNED70A6A 65'' 165 Ekran Uydu Alıcılı 4K Ultra HD Smart QNED TV","image":"https://image01.idefix.com/resize/{size}product/13804573/lg65qned70a6a-65-165-ekran-uydu-alicili-4k-ultra-hd-smart-qned-tv-68c039269bb96.jpg","description":"LG  65QNED70A6A 65'' 165 Ekran Uydu Alıcılı 4K Ultra HD Smart QNED TV yorumlarını inceleyin, idefix’e özel indirimli fiyata satın alın.","brand":{"@type":"Organization","name":"LG"},"sku":"8806096434611","gtin13":"8806096434611","aggregateRating":{"@type":"AggregateRating","ratingValue":4.8,"reviewCount":32,"bestRating":5},"offers":{"@type":"Offer","url":"https://www.idefix.com/lg-65qned70a6a-65-165-ekran-uydu-alicili-4k-ultra-hd-smart-qned-tv-p-13804573","priceCurrency":"TRY","price":46449,"itemCondition":"https://schema.org/NewCondition","availability":"https://schema.org/InStock"},"review":[{"@type":"Review","reviewBody":"Satıcı tv’yi ilk iş günü gönderdi; kargo firması da ertesi gün ankara’ya ulaştırdı.\\ntv’yi beğendim.\\nRenk ayarını yapın."}]}</script>
  `;
  const $lg = cheerio.load(lgHtml);
  assert.strictEqual(scraper.scrapePrice($lg), 46449);
  const ratingLg = await scraper.scrapeRating($lg);
  assert.strictEqual(ratingLg.ratingValue, 4.8);
  assert.strictEqual(ratingLg.ratingCount, 32);
  assert.strictEqual(scraper.scrapeBrand($lg), 'LG');
}

module.exports = { run };
