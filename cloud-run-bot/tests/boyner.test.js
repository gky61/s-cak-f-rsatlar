const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');
const BoynerScraper = require('../scrapers/boyner_scraper');

describe('BoynerScraper Tests', () => {
  const scraper = new BoynerScraper();

  test('canHandle should return true for boyner.com.tr URLs', () => {
    expect(scraper.canHandle('https://www.boyner.com.tr/tommy-hilfiger-tas-kadin-omuz-cantasi-aw0aw18463aep-p-15891128')).toBe(true);
    expect(scraper.canHandle('https://boyner.com.tr/armani-p-797957')).toBe(true);
    expect(scraper.canHandle('https://www.hepsiburada.com/item')).toBe(false);
  });

  test('Product #1 (Tommy Hilfiger Bag) - Should scrape title, brand, prices and ratings correctly', () => {
    const htmlPath = path.join(__dirname, '../../scratch/boyner_1.html');
    if (!fs.existsSync(htmlPath)) return;
    const html = fs.readFileSync(htmlPath, 'utf-8');
    const $ = cheerio.load(html);

    expect(scraper.scrapeTitle($)).toContain('Tommy Hilfiger');
    expect(scraper.scrapeBrand($)).toBe('Tommy Hilfiger');
    const price = scraper.scrapePrice($);
    expect(price).toBe(2349);
    const originalPrice = scraper.scrapeOriginalPrice($, price);
    expect(originalPrice).toBe(3299);
    const rating = scraper.scrapeRating($);
    expect(rating.ratingValue).toBe(4.1);
    expect(rating.ratingCount).toBe(7);
  });

  test('Product #2 (Armani Perfume) - Should scrape title, brand, prices and ratings correctly', () => {
    const htmlPath = path.join(__dirname, '../../scratch/boyner_2.html');
    if (!fs.existsSync(htmlPath)) return;
    const html = fs.readFileSync(htmlPath, 'utf-8');
    const $ = cheerio.load(html);

    expect(scraper.scrapeTitle($)).toContain('Armani');
    expect(scraper.scrapeBrand($)).toBe('Armani');
    const price = scraper.scrapePrice($);
    expect(price).toBe(5625);
    const originalPrice = scraper.scrapeOriginalPrice($, price);
    expect(originalPrice).toBe(7500);
    const rating = scraper.scrapeRating($);
    expect(rating.ratingValue).toBe(4.2);
    expect(rating.ratingCount).toBe(452);
  });

  test('Product #3 (New Balance 530) - Should scrape title, brand, price and ratings correctly', () => {
    const htmlPath = path.join(__dirname, '../../scratch/boyner_3.html');
    if (!fs.existsSync(htmlPath)) return;
    const html = fs.readFileSync(htmlPath, 'utf-8');
    const $ = cheerio.load(html);

    expect(scraper.scrapeTitle($)).toContain('New Balance');
    expect(scraper.scrapeBrand($)).toBe('New Balance');
    const price = scraper.scrapePrice($);
    expect(price).toBe(7499);
    const originalPrice = scraper.scrapeOriginalPrice($, price);
    expect(originalPrice).toBeNull();
    const rating = scraper.scrapeRating($);
    expect(rating.ratingValue).toBe(3.9);
    expect(rating.ratingCount).toBe(30);
  });

  test('Product #4 (Fabrika Polo T-Shirt) - Should scrape title, brand, prices and ratings (4.5/17) correctly', () => {
    const htmlPath = path.join(__dirname, '../../scratch/boyner_4.html');
    if (!fs.existsSync(htmlPath)) return;
    const html = fs.readFileSync(htmlPath, 'utf-8');
    const $ = cheerio.load(html);

    expect(scraper.scrapeTitle($)).toContain('Polo T-Shirt');
    expect(scraper.scrapeBrand($)).toBe('Fabrika');
    const price = scraper.scrapePrice($);
    expect(price).toBe(649.95);
    const originalPrice = scraper.scrapeOriginalPrice($, price);
    expect(originalPrice).toBe(1399);
    const rating = scraper.scrapeRating($);
    expect(rating.ratingValue).toBe(4.5);
    expect(rating.ratingCount).toBe(17);
  });

  test('Product #5 (Patrizia Pepe Loafer) - Should scrape exact 11999 TL price without truncation', () => {
    const htmlPath = path.join(__dirname, '../../scratch/boyner_issue1.html');
    const html = fs.existsSync(htmlPath)
      ? fs.readFileSync(htmlPath, 'utf-8')
      : `
        <html>
          <head>
            <script>
              var data = {"PriceInfo":{"Price":"11.999","OldPrice":"23.299","CampaignInfo":"%48 İndirim"}};
            </script>
          </head>
          <body>
            <h1>Patrizia Pepe Ekru Kadın Deri Loafer</h1>
            <span class="price_priceMain__DrVVQ">
              <span class="price_priceMainText__6p5Zp">Sepette</span>11.999 TL
            </span>
            <span class="price_priceOldPrice__test">23.299 TL</span>
          </body>
        </html>
      `;
    const $ = cheerio.load(html);

    expect(scraper.scrapeTitle($)).toContain('Patrizia Pepe');
    const price = scraper.scrapePrice($);
    expect(price).toBe(11999);
    const originalPrice = scraper.scrapeOriginalPrice($, price);
    expect(originalPrice).toBe(23299);
    expect(scraper.scrapePriceLabel($)).toBe('%48 İndirim');
  });

  test('Product #6 (Azzaro Wanted Absolu) - Should scrape exact 7910 TL price without truncation', () => {
    const htmlPath = path.join(__dirname, '../../scratch/boyner_issue2.html');
    const html = fs.existsSync(htmlPath)
      ? fs.readFileSync(htmlPath, 'utf-8')
      : `
        <html>
          <head>
            <script>
              var data = {"PriceInfo":{"Price":"7.910","OldPrice":"11.300","CampaignInfo":"%30 İndirim"}};
            </script>
          </head>
          <body>
            <h1>Azzaro Wanted Absolu</h1>
            <span class="price_priceMain__DrVVQ">
              <span class="price_priceMainText__6p5Zp">Sepette</span>7.910 TL
            </span>
            <span class="price_priceOldPrice__test">11.300 TL</span>
          </body>
        </html>
      `;
    const $ = cheerio.load(html);

    expect(scraper.scrapeTitle($)).toContain('Azzaro');
    const price = scraper.scrapePrice($);
    expect(price).toBe(7910);
    const originalPrice = scraper.scrapeOriginalPrice($, price);
    expect(originalPrice).toBe(11300);
    expect(scraper.scrapePriceLabel($)).toBe('%30 İndirim');
  });

  test('Product #7 (Tommy Hilfiger Blue Bag) - Should scrape 3014.25 TL and 4019 TL correctly', () => {
    const htmlPath = path.join(__dirname, '../../scratch/boyner_issue3.html');
    const html = fs.existsSync(htmlPath)
      ? fs.readFileSync(htmlPath, 'utf-8')
      : `
        <html>
          <head>
            <script>
              var data = {"PriceInfo":{"Price":"3.014,25","OldPrice":"4.019","CampaignInfo":"%25 İndirim"}};
            </script>
          </head>
          <body>
            <h1>Tommy Hilfiger Mavi Kadın Çanta</h1>
            <span class="price_priceMain__DrVVQ">
              <span class="price_priceMainText__6p5Zp">Sepette</span>3.014,25 TL
            </span>
            <span class="price_priceOldPrice__test">4.019 TL</span>
          </body>
        </html>
      `;
    const $ = cheerio.load(html);

    expect(scraper.scrapeTitle($)).toContain('Tommy Hilfiger');
    const price = scraper.scrapePrice($);
    expect(price).toBe(3014.25);
    const originalPrice = scraper.scrapeOriginalPrice($, price);
    expect(originalPrice).toBe(4019);
    expect(scraper.scrapePriceLabel($)).toBe('%25 İndirim');
  });
});
