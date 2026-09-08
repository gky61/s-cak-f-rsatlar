const assert = require('assert');
const affiliateManager = require('../affiliate_manager');
const linkScraperService = require('../link_scraper_service');

async function runTests() {
  console.log('=== Hepsiburada LinkGelir (Adjust 7t4g.adj.st) Node.js Integration Tests ===\n');

  const adminAccount = 'muratcan gokyokus';
  const canonicalUrl = 'https://www.hepsiburada.com/altinyildiz-classics-erkek-100-pamuk-v-yaka-lacivert-slim-fit-duz-t-shirt-p-HBCV000003LVO6?magaza=Alt%C4%B1ny%C4%B1ld%C4%B1z%20Classics';
  const sku = 'HBCV000003LVO6';

  // Test 1: affiliateManager.canHandle
  console.log('Test 1: affiliateManager.canHandle recognition');
  assert(affiliateManager.canHandle(canonicalUrl), 'Must handle canonical hepsiburada.com');
  assert(affiliateManager.canHandle('https://app.hb.biz/xh5GZgJFADek'), 'Must handle app.hb.biz');
  assert(affiliateManager.canHandle('https://hb.biz/test'), 'Must handle hb.biz');
  assert(affiliateManager.canHandle('https://7t4g.adj.st/product?sku=HBCV000003LVO6'), 'Must handle 7t4g.adj.st');
  console.log('✅ Test 1 Passed: canHandle tüm Hepsiburada ve Adjust varyantlarını tanıdı.\n');

  // Test 2: Synthesize Hepsiburada Adjust Affiliate URL via affiliateManager.convert
  console.log('Test 2: Synthesize Hepsiburada Adjust Affiliate URL via affiliateManager.convert');
  const synthesizedAffiliateUrl = affiliateManager.convert(canonicalUrl, {
    hepsiburadaAffiliateEnabled: true,
    hepsiburadaAccountName: adminAccount
  });

  console.log('Synthesized Affiliate URL:\n  ', synthesizedAffiliateUrl);
  assert(synthesizedAffiliateUrl.startsWith('https://7t4g.adj.st/product'), 'Must start with 7t4g.adj.st/product');
  assert(synthesizedAffiliateUrl.includes(`sku=${sku}`), 'SKU must be HBCV000003LVO6');
  assert(synthesizedAffiliateUrl.includes('adj_t=10zuiki3_y4q2fze'), 'Tracker token must be default');
  assert(synthesizedAffiliateUrl.includes('adj_campaign=ux_gelistirmeleri'), 'Campaign must be ux_gelistirmeleri');
  assert(synthesizedAffiliateUrl.includes('adj_adgroup=muratcan%20gokyokus') || synthesizedAffiliateUrl.includes('adj_adgroup=muratcan+gokyokus'), 'Admin account must be encoded');
  assert(synthesizedAffiliateUrl.includes(`adj_creative=${sku}`), 'Creative must match SKU');
  assert(synthesizedAffiliateUrl.includes('utm_source=influencer'), 'utm_source must be influencer');
  assert(synthesizedAffiliateUrl.includes('utm_medium=linkgelir'), 'utm_medium must be linkgelir');
  assert(synthesizedAffiliateUrl.includes('adj_fallback='), 'adj_fallback must be present');
  console.log('✅ Test 2 Passed: affiliateManager.convert eksiksiz 7t4g.adj.st linki üretti.\n');

  // Test 3: isAlreadyAffiliate
  console.log('Test 3: affiliateManager.isAlreadyAffiliate verification');
  assert(affiliateManager.isAlreadyAffiliate(synthesizedAffiliateUrl, adminAccount), 'Our Adjust link must be recognized as already affiliate');
  assert(!affiliateManager.isAlreadyAffiliate(canonicalUrl), 'Canonical URL must NOT be recognized as affiliate');
  assert(!affiliateManager.isAlreadyAffiliate('https://app.hb.biz/xh5GZgJFADek'), 'Shortlink must NOT be recognized as affiliate');
  
  const competitorUrl = 'https://7t4g.adj.st/product?sku=HBCV000003LVO6&adj_t=10zuiki3_y4q2fze&adj_adgroup=rakip_influencer&adj_fallback=' + encodeURIComponent(canonicalUrl);
  assert(!affiliateManager.isAlreadyAffiliate(competitorUrl, adminAccount), 'Competitor Adjust link must NOT be recognized as our affiliate');
  console.log('✅ Test 3 Passed: isAlreadyAffiliate yetkilendirmesi kusursuz çalışıyor.\n');

  // Test 4: Anti-Hijacking of Competitor Adjust Link
  console.log('Test 4: Anti-Hijacking and Retargeting Competitor Adjust Link to Admin Account');
  const retargetedUrl = affiliateManager.convert(competitorUrl, {
    hepsiburadaAffiliateEnabled: true,
    hepsiburadaAccountName: adminAccount
  });
  console.log('Retargeted URL:\n  ', retargetedUrl);
  assert(retargetedUrl.includes('adj_adgroup=muratcan%20gokyokus') || retargetedUrl.includes('adj_adgroup=muratcan+gokyokus'), 'Must be retargeted to admin account');
  assert(!retargetedUrl.includes('rakip_influencer'), 'Competitor account MUST be removed');
  assert(retargetedUrl.includes(`sku=${sku}`), 'SKU must be preserved');
  console.log('✅ Test 4 Passed: Rakip Adjust linki admin hesabına (anti-hijack) dönüştürüldü.\n');

  // Test 5: Kill-Switch / Fallback when disabled
  console.log('Test 5: Kill-Switch / Fallback when hepsiburadaAffiliateEnabled is false');
  const fallbackFromCompetitor = affiliateManager.convert(competitorUrl, {
    hepsiburadaAffiliateEnabled: false
  });
  console.log('Fallback from competitor:\n  ', fallbackFromCompetitor);
  assert(!fallbackFromCompetitor.includes('7t4g.adj.st'), 'Must not contain 7t4g.adj.st when disabled');
  assert(fallbackFromCompetitor.includes('hepsiburada.com'), 'Must fallback to hepsiburada.com');
  assert(fallbackFromCompetitor.includes(sku), 'Must preserve product SKU');
  console.log('✅ Test 5 Passed: Kill-switch kapalıyken tertemiz organik Hepsiburada linkine unwrap edildi.\n');

  // Test 6: cleanProductUrl
  console.log('Test 6: cleanProductUrl verification');
  const cleanFromSynthesized = affiliateManager.cleanProductUrl(synthesizedAffiliateUrl);
  console.log('Clean from synthesized:\n  ', cleanFromSynthesized);
  assert(cleanFromSynthesized.includes('hepsiburada.com'), 'Clean URL must be hepsiburada.com');
  assert(!cleanFromSynthesized.includes('7t4g.adj.st'), 'Clean URL must not be 7t4g.adj.st');
  assert(cleanFromSynthesized.includes('magaza=Alt'), 'Clean URL preserves seller store query');

  const dirtyWebUrl = 'https://www.hepsiburada.com/altinyildiz-classics-erkek-100-pamuk-v-yaka-lacivert-slim-fit-duz-t-shirt-p-HBCV000003LVO6?magaza=Alt%C4%B1ny%C4%B1ld%C4%B1z%20Classics&utm_source=affiliate&wt_af=123';
  const cleanFromWeb = affiliateManager.cleanProductUrl(dirtyWebUrl);
  assert(!cleanFromWeb.includes('utm_source'), 'Tracking params must be stripped');
  assert(!cleanFromWeb.includes('wt_af'), 'wt_af must be stripped');
  console.log('✅ Test 6 Passed: cleanProductUrl temiz ürün linkini kusursuz çıkardı.\n');

  // Test 7: Live resolution of user app.hb.biz shortlinks
  console.log('Test 7: Testing live resolution of user app.hb.biz shortlinks via linkScraperService');
  const testLinks = [
    'https://app.hb.biz/xh5GZgJFADek',
    'https://app.hb.biz/0x1QpfQKpgNa',
    'https://app.hb.biz/fjKKWyLJLLCE',
    'https://app.hb.biz/AQQCeOBmGiqx'
  ];

  for (let i = 0; i < testLinks.length; i++) {
    const shortLink = testLinks[i];
    console.log(`  Resolving link ${i + 1}/${testLinks.length}: ${shortLink}`);
    const resolved = await linkScraperService.resolveUrlRedirects(shortLink);
    console.log(`  -> Resolved: ${resolved}`);
    assert(resolved.includes('hepsiburada.com') || resolved.includes('7t4g.adj.st'), 'Must resolve to Hepsiburada or Adjust');
  }
  console.log('✅ Test 7 Passed: Tüm kullanıcı app.hb.biz linkleri başarıyla çözümlendi.\n');

  console.log('🎉 All Node.js Hepsiburada LinkGelir (Adjust) Affiliate Tests Passed Successfully!');
}

runTests().catch(err => {
  console.error('❌ Test Failed:', err);
  process.exit(1);
});
