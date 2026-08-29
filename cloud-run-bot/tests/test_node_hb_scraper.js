const cheerio = require('cheerio');
const HepsiburadaScraper = require('../scrapers/hepsiburada_scraper');

const urls = [
  { url: 'https://app.hb.biz/IJkBneLO0EMd', name: 'Case 1 (False Positive): Le Petit Marseillais', expected: null },
  { url: 'https://app.hb.biz/557ruKNKje27', name: 'Case 2 (False Negative): Isana Men Duş Jeli', expected: 'Premium ile' },
  { url: 'https://app.hb.biz/FLn8axWk18kf', name: 'Case 3 (False Positive): Tudors Polo', expected: null },
  { url: 'https://app.hb.biz/82purTtw8lCz', name: 'Case 4 (False Positive): Loreal Duş Jeli', expected: null },
  { url: 'https://app.hb.biz/1NtpRgwjkbVb', name: 'Case 5 (False Positive): Loreal Barber Club', expected: null },
  { url: 'https://app.hb.biz/fmLh1PwftM9s', name: 'Case 6 (False Negative): Mirissa Lab', expected: 'Premium ile' },
  { url: 'https://app.hb.biz/MTfmiMR9EWpo', name: 'Case 7 (False Negative): Baren Coss', expected: 'Premium ile' },
];

async function resolveHbBiz(url) {
  try {
    const res = await fetch(url, { redirect: 'manual' });
    const location = res.headers.get('location');
    if (location) {
      const u = new URL(location);
      const fallback = u.searchParams.get('adjust_fallback') || u.searchParams.get('adj_fallback');
      if (fallback) return decodeURIComponent(fallback);
      return location;
    }
  } catch (e) {}
  return url;
}

async function run() {
  console.log('=== TESTING NODE.JS HEPSIBURADA SCRAPER ===');
  let passedCount = 0;

  for (const item of urls) {
    const scraper = new HepsiburadaScraper();
    const resolvedUrl = await resolveHbBiz(item.url);
    const res = await fetch(resolvedUrl, {
      headers: {
        'User-Agent': 'WhatsApp/2.23.4.15 A',
        'Accept': 'text/html'
      }
    });
    const html = await res.text();
    const $ = cheerio.load(html);

    const price = await scraper.scrapePrice($);
    const priceLabel = scraper.scrapePriceLabel($);

    const passed = priceLabel === item.expected;
    if (passed) passedCount++;

    console.log(`[${passed ? 'PASS' : 'FAIL'}] ${item.name}`);
    console.log(`       Price: ${price}, Label: ${priceLabel} (Expected: ${item.expected})`);
  }

  console.log(`\nResult: ${passedCount} / ${urls.length} passed.`);
  if (passedCount === urls.length) {
    process.exit(0);
  } else {
    process.exit(1);
  }
}

run();
