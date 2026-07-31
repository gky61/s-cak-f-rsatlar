const assert = require('assert');
const domainAllowlist = require('../domain_allowlist');

// Extract store logic function test
function extractStoreFromLink(link, text) {
  let store = 'Diğer';
  const lowerLink = link ? link.toLowerCase() : '';
  let hostname = '';
  if (link) {
    try {
      hostname = new URL(link).hostname.toLowerCase();
    } catch (_) {
      hostname = lowerLink;
    }
  }

  if (hostname.includes('getir') || lowerLink.includes('getir.com') || lowerLink.includes('getir.onelink.me') || lowerLink.includes('onelink.me')) store = 'Getir';
  else if (hostname.includes('migros') || lowerLink.includes('migros.com')) store = 'Migros';
  else if (hostname.includes('trendyol') || lowerLink.includes('trendyol.com') || lowerLink.includes('ty.gl')) store = 'Trendyol';
  else if (hostname.includes('hepsiburada') || lowerLink.includes('hepsiburada.com') || lowerLink.includes('hb.biz')) store = 'Hepsiburada';
  else if (hostname.includes('amazon') || lowerLink.includes('amazon.') || lowerLink.includes('amzn.') || lowerLink.includes('amzlinks.')) store = 'Amazon';
  else if (hostname.includes('n11') || lowerLink.includes('n11.com')) store = 'N11';
  else if (hostname.includes('a101') || lowerLink.includes('a101.com')) store = 'A101';
  else if (hostname.includes('bim.com') || lowerLink.includes('bim.com.tr')) store = 'Bim';
  else if (hostname.includes('sokmarket') || hostname.includes('ceptesok')) store = 'Şok';

  return store;
}

function runTests() {
  console.log('🧪 Testing Getir onelink.me store resolution...\n');

  const testUrl = 'https://getir.onelink.me/kxRB/pds6bimw';
  
  // 1. extractStoreFromLink
  const store = extractStoreFromLink(testUrl, '');
  console.log(`1. extractStoreFromLink("${testUrl}") ->`, store);
  assert.strictEqual(store, 'Getir');

  // 2. domainAllowlist isDomainAllowed
  const isAllowed = domainAllowlist.isDomainAllowed(testUrl);
  console.log(`2. isDomainAllowed("${testUrl}") ->`, isAllowed);
  assert.strictEqual(isAllowed, true);

  // 3. domainAllowlist getStoreKeyForUrl
  const storeKey = domainAllowlist.getStoreKeyForUrl(testUrl);
  console.log(`3. getStoreKeyForUrl("${testUrl}") ->`, storeKey);
  assert.strictEqual(storeKey, 'getir');

  console.log('\n✅ ALL GETIR ONELINK STORE TESTS PASSED!');
}

runTests();
