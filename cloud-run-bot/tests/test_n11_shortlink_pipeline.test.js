const assert = require('assert');
const linkScraperService = require('../link_scraper_service');
const domainAllowlist = require('../domain_allowlist');

async function testN11ShortlinkPipeline() {
  console.log('🧪 Testing N11 Shortlink Pipeline & Allowlist...\n');

  const rawLink = 'https://sl.n11.com/n/vssdx22';
  const rawLinks = [rawLink];

  // Pipeline simulation (matching telegram_bot.js logic)
  let mainLink = null;
  for (const link of rawLinks) {
    // 1. Direct match check (must be domain allowed AND a valid product url)
    if (domainAllowlist.isDomainAllowed(link) && domainAllowlist.isProductUrl(link)) {
      mainLink = link;
      console.log(`🎯 [ALLOWLIST MATCH] Desteklenen mağaza ürün linki bulundu: ${mainLink}`);
      break;
    }

    // 2. Resolve shortlink / redirects
    const resolvedLink = await linkScraperService.resolveUrlRedirects(link);
    if (domainAllowlist.isDomainAllowed(resolvedLink)) {
      mainLink = resolvedLink;
      console.log(`🎯 [ALLOWLIST MATCH] Desteklenen mağaza ürün linki bulundu (Çözülen): ${mainLink} (Orijinal: ${link})`);
      break;
    }
  }

  assert.ok(mainLink, 'mainLink must not be null');
  console.log(`\n1. mainLink: ${mainLink}`);

  // Product Path Validation
  const isProduct = domainAllowlist.isProductUrl(mainLink);
  console.log(`2. isProductUrl(mainLink): ${isProduct}`);
  assert.strictEqual(isProduct, true, 'Resolved N11 link must pass isProductUrl!');

  // Store Key
  const storeKey = domainAllowlist.getStoreKeyForUrl(mainLink);
  console.log(`3. getStoreKeyForUrl(mainLink): ${storeKey}`);
  assert.strictEqual(storeKey, 'n11', 'Store key must be n11');

  // Scraping
  console.log('\n4. Running scrapeProductFromUrl...');
  const result = await linkScraperService.scrapeProductFromUrl(mainLink);
  console.log(`   -> Title: ${result.title}`);
  console.log(`   -> Price: ${result.price} TL`);
  console.log(`   -> Image: ${result.imageUrl}`);

  assert.ok(result.title && result.title.length > 0, 'Scraped title must not be empty');
  assert.ok(result.price !== null && result.price > 0, 'Scraped price must not be null or 0');
  assert.ok(result.imageUrl && result.imageUrl.length > 0, 'Scraped image URL must not be empty');

  console.log('\n✅ N11 SHORTLINK PIPELINE TEST PASSED SUCCESSFULLY!');
}

testN11ShortlinkPipeline();
