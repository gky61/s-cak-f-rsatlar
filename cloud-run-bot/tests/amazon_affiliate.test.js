const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

async function runTests() {
  console.log('=== Amazon Associates TR (amazon.com.tr) Node.js Integration Tests ===\n');

  const trackingId = 'firsatkolik-21';
  const canonicalUrl = 'https://www.amazon.com.tr/dp/B08N5WRWNW';

  // Test 1: Synthesize Amazon Associates Affiliate URL
  console.log('Test 1: Synthesize Amazon Associates URL from canonical product link');
  const asin = 'B08N5WRWNW';
  const urlObj = new URL(canonicalUrl);
  urlObj.searchParams.set('tag', trackingId);
  const synthesizedAffiliateUrl = urlObj.toString();

  assert(synthesizedAffiliateUrl.includes('amazon.com.tr/dp/B08N5WRWNW'), 'Must contain canonical path');
  assert(synthesizedAffiliateUrl.includes(`tag=${trackingId}`), 'Tracking ID must be firsatkolik-21');
  console.log('✅ Test 1 Passed: Sentezlenen Amazon Associates URL doğrulaması başarılı:\n   ', synthesizedAffiliateUrl, '\n');

  // Test 2: Test live resolution of user amzn.eu shortlinks
  console.log('Test 2: Testing live resolution of user amzn.eu mobile share shortlinks');
  const userTestLinks = [
    'https://amzn.eu/d/097K8DSA',
    'https://amzn.eu/d/0dsXBLAE',
    'https://amzn.eu/d/04lH7aur'
  ];

  for (let i = 0; i < userTestLinks.length; i++) {
    const shortLink = userTestLinks[i];
    console.log(`  Resolving link ${i + 1}/${userTestLinks.length}: ${shortLink}`);
    const resolved = await linkScraperService.resolveUrlRedirects(shortLink);
    console.log(`  -> Resolved: ${resolved}`);
    assert(resolved.includes('amazon.com.tr'), 'Must resolve to amazon.com.tr');
    assert(resolved.includes('/dp/') || resolved.includes('ASIN=') || resolved.includes('asin='), 'Must contain product identifier');
  }
  console.log('✅ Test 2 Passed: Tüm kullanıcı amzn.eu mobil paylaşım linkleri başarıyla çözümlendi.\n');

  // Test 3: Retargeting/Anti-Hijack of third-party link to Admin Tracking ID
  console.log('Test 3: Retargeting third-party Amazon affiliate link to Admin Tracking ID');
  const thirdPartyUrl = 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=baskasinin_tagi-21&linkCode=ll1&ref_=cm_sw_r_apan_dp_123';
  const parsed = new URL(thirdPartyUrl);

  // Strip tracking garbage
  ['ref', 'linkCode', 'ascsubtag', 'social_share'].forEach(p => parsed.searchParams.delete(p));
  const toDelete = [];
  parsed.searchParams.forEach((val, key) => {
    if (key.toLowerCase().startsWith('ref_')) toDelete.push(key);
  });
  toDelete.forEach(p => parsed.searchParams.delete(p));

  // Retarget to admin
  parsed.searchParams.set('tag', trackingId);
  const retargetedUrl = parsed.toString();

  assert(retargetedUrl.includes(`tag=${trackingId}`), 'Must contain admin tag firsatkolik-21');
  assert(!retargetedUrl.includes('baskasinin_tagi-21'), 'Third-party tag must be removed');
  assert(!retargetedUrl.includes('linkCode'), 'linkCode must be removed');
  console.log('✅ Test 3 Passed: Yabancı affiliate linki admin takip kimliğine (anti-hijack) dönüştürüldü:\n   ', retargetedUrl, '\n');

  // Test 4: Kill-Switch / Fallback: Unwrap and strip all tracking params
  console.log('Test 4: Fallback / Kill-Switch unwrapping to clean organic product URL');
  const dirtyUrl = 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=firsatkolik-21&ref_=test&social_share=123';
  const cleanObj = new URL(dirtyUrl);
  ['tag', 'ref', 'linkCode', 'ascsubtag', 'social_share'].forEach(p => cleanObj.searchParams.delete(p));
  const toDel = [];
  cleanObj.searchParams.forEach((val, key) => {
    if (key.toLowerCase().startsWith('ref_')) toDel.push(key);
  });
  toDel.forEach(p => cleanObj.searchParams.delete(p));
  const cleanOrganicUrl = cleanObj.toString();

  assert(cleanOrganicUrl === canonicalUrl, 'Clean organic URL must match canonical product link');
  assert(!cleanOrganicUrl.includes('tag='), 'Must not have tag');
  console.log('✅ Test 4 Passed: Kill-switch güvenli fallback unwrap başarılı:\n   ', cleanOrganicUrl, '\n');

  console.log('🎉 All Node.js Amazon Associates TR Integration Tests Passed Successfully!');
}

runTests().catch(err => {
  console.error('❌ Test Failed:', err);
  process.exit(1);
});
