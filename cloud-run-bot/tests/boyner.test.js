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
});
