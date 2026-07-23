const assert = require('assert');
const cheerio = require('cheerio');
const HavitScraper = require('../scrapers/havit_scraper');

async function run() {
  const scraper = new HavitScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.havitstore.com.tr/havit-hv-ms745-gaming-mouse'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. DOM-based rating
  const htmlDom = `
    <span class="comment-count-left">328</span>
    <div class="right-stars">
      <div class="comment-count" style="margin-right:8px;font-size:32px;">4.75</div>
    </div>
  `;
  const $dom = cheerio.load(htmlDom);
  const ratingDom = await scraper.scrapeRating($dom);
  assert.strictEqual(ratingDom.ratingValue, 4.75, 'ratingValue should be 4.75 from .comment-count');
  assert.strictEqual(ratingDom.ratingCount, 328, 'ratingCount should be 328 from .comment-count-left');

  // 3. Ticimax Script model fallback
  const htmlScript = `
    <span id="divYorumSayisi">(15)</span>
    <script type="text/javascript">
      var productDetailModel = {"productId":375,"productName":"Havit Gamenote GK60 PRO","rating":4.8,"brandName":"Havit"};
    </script>
  `;
  const $script = cheerio.load(htmlScript);
  const ratingScript = await scraper.scrapeRating($script);
  assert.strictEqual(ratingScript.ratingValue, 4.8, 'ratingValue should be 4.8 from Ticimax script');
  assert.strictEqual(ratingScript.ratingCount, 15, 'ratingCount should be 15 from #divYorumSayisi');
  assert.strictEqual(scraper.scrapeBrand($script), 'Havit', 'brand should be Havit from Ticimax script');

  // 4. YG Digital API Fallback
  const htmlApi = `
    <input type="hidden" name="ctl00$mainHolder$UrunDetay$hddnUrunID" id="hddnUrunID" value="397" />
    <script type="text/javascript">
      var productDetailModel = {"productId":375,"productName":"Havit GK60 PRO","stockCode":"6939119039868"};
    </script>
  `;
  const $api = cheerio.load(htmlApi);
  const ratingApi = await scraper.scrapeRating($api);
  assert.strictEqual(ratingApi.ratingValue, 4.75, 'ratingValue should be 4.75 from YG Digital API');
  assert.strictEqual(ratingApi.ratingCount, 328, 'ratingCount should be 328 from YG Digital API');
}

module.exports = { run };
