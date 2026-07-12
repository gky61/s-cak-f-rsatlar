const assert = require('assert');
const cheerio = require('cheerio');
const MangoScraper = require('../scrapers/mango_scraper');

function run() {
  const scraper = new MangoScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://shop.mango.com/tr/kadin/ceketler-ve-blazerler/deri-ceket_37082888'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. normal price, title, description, image
  const html1 = `
    <head>
      <meta property="og:title" content="Dökümlü Trençkot">
      <meta property="og:image" content="https://st.mango.com/rcs/pics/static/T3/fotos/S20/37082888_30.jpg">
      <meta name="description" content="Kemer detaylı dökümlü pamuklu trençkot.">
    </head>
    <body>
      <script>
        self.__next_f.push([1,"67:[\\"\$,\\"\$L85\\",null,{\\"showAdditionalCurrencies\\":\\"\$undefined\\",\\"discountRate\\":\\"\$undefined\\",\\"hideSaleOrPromoPrice\\":false,\\"price\\":{\\"amount\\":2999.99,\\"formatted\\":\\"2.999,99 TL\\",\\"additionalPrices\\":[]},\\"crossedOutPrices\\":[]}]\\n"]);
      </script>
    </body>
  `;
  const $1 = cheerio.load(html1);

  assert.strictEqual(scraper.scrapePrice($1), 2999.99);
  assert.strictEqual(scraper.scrapeTitle($1), 'Dökümlü Trençkot');
  assert.strictEqual(scraper.scrapeDescription($1), 'Kemer detaylı dökümlü pamuklu trençkot.');
  assert.strictEqual(scraper.scrapeImage($1, 'https://shop.mango.com/tr/kadin/ceketler-ve-blazerler/deri-ceket_37082888'), 'https://st.mango.com/rcs/pics/static/T3/fotos/S20/37082888_30.jpg');

  // 3. discounted price
  const html2 = `
    <body>
      <script>
        self.__next_f.push([1,"66:[\\"\$,\\"\$L82\\",null,{\\"showAdditionalCurrencies\\":\\"\$undefined\\",\\"discountRate\\":47,\\"hideSaleOrPromoPrice\\":false,\\"price\\":{\\"amount\\":1599.99,\\"formatted\\":\\"1.599,99 TL\\",\\"additionalPrices\\":[]},\\"crossedOutPrices\\":[{\\"amount\\":2999.99}]}]\\n"]);
      </script>
    </body>
  `;
  const $2 = cheerio.load(html2);
  assert.strictEqual(scraper.scrapePrice($2), 1599.99);

  // 4. escaped quotes Next.js payload
  const html3 = `
    <body>
      <script>
        self.__next_f.push([1,"T001\\":{\\"compositionId\\":\\"T001\\",\\"prices\\":{\\"price\\":3699.99,\\"starPrice\\":false,\\"type\\":\\"PVP\\"}}],\\"id\\":\\"37061358\\""]);
      </script>
    </body>
  `;
  const $3 = cheerio.load(html3);
  assert.strictEqual(scraper.scrapePrice($3), 3699.99);

  // 5. nested escaped amount Next.js payload
  const html4 = `
    <body>
      <script>
        self.__next_f.push([1,"country\\":\\"$4:props:children:1\\",\\"channel\\":\\"shop\\",\\"price\\":{\\"amount\\":1599.99,\\"formatted\\":\\"1.599,99 TL\\"}"]);
      </script>
    </body>
  `;
  const $4 = cheerio.load(html4);
  assert.strictEqual(scraper.scrapePrice($4), 1599.99);
}

module.exports = { run };
