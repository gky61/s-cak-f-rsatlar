const assert = require('assert');
const linkScraperService = require('../link_scraper_service');
const domainAllowlist = require('../domain_allowlist');

async function testPipeline() {
  console.log('🧪 Testing Getir Shortlink Pipeline & Allowlist...\n');

  const rawLink = 'https://getir.onelink.me/kxRB/pds6bimw';

  // 1. Resolve redirect
  console.log(`1. Resolving shortlink: ${rawLink}...`);
  const resolvedLink = await linkScraperService.resolveUrlRedirects(rawLink);
  console.log(`   -> Resolved Link: ${resolvedLink}`);

  // 2. Allowlist check on resolved link
  const isAllowed = domainAllowlist.isDomainAllowed(resolvedLink);
  console.log(`2. isDomainAllowed(resolvedLink) -> ${isAllowed}`);
  assert.strictEqual(isAllowed, true, 'Resolved link (getir.com) must be allowed in allowlist!');

  // 3. Store Key on resolved link
  const storeKey = domainAllowlist.getStoreKeyForUrl(resolvedLink);
  console.log(`3. getStoreKeyForUrl(resolvedLink) -> ${storeKey}`);
  assert.strictEqual(storeKey, 'getir');

  console.log('\n✅ PIPELINE TEST PASSED! Allowlist does not need shortlink domains because redirected URL is getir.com.');
}

testPipeline();
