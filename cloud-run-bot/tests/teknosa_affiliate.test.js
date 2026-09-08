const assert = require('assert');
const affiliateManager = require('../affiliate_manager');
const linkScraperService = require('../link_scraper_service');

async function runTests() {
  console.log('=== Teknosa Paylaş Kazan (Winfluenced / TUNE HasOffers) Node.js Integration Tests ===\n');

  const adminUserId = '906bd201-92dc-4898-914a-10309b2cd576';
  const canonicalProductUrl = 'https://www.teknosa.com/yenilenmis-iphone-xr-128-gb-mavi-cep-telefonu-1-yil-garantili-a-kalite-p-790182989?shopId=2442';

  // Test 1: affiliateManager.canHandle recognition
  console.log('Test 1: affiliateManager.canHandle recognition');
  assert(affiliateManager.canHandle(canonicalProductUrl), 'Must handle canonical teknosa.com');
  assert(affiliateManager.canHandle('https://paylaskazan.teknosa.com/teknosa-F8NSB38NC3'), 'Must handle paylaskazan.teknosa.com');
  assert(affiliateManager.canHandle('https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016'), 'Must handle rdr.btrck.com');
  assert(affiliateManager.canHandle('https://btrck.com/test'), 'Must handle btrck.com');
  console.log('✅ Test 1 Passed: canHandle tüm Teknosa, Paylaş Kazan ve TUNE varyantlarını tanıdı.\n');

  // Test 2: Synthesize Teknosa TUNE Affiliate URL via affiliateManager.convert
  console.log('Test 2: Synthesize Teknosa TUNE Affiliate URL via affiliateManager.convert');
  const synthesizedAffiliateUrl = affiliateManager.convert(canonicalProductUrl, {
    teknosaAffiliateEnabled: true,
    teknosaUserId: adminUserId
  });

  console.log('Synthesized Affiliate URL:\n  ', synthesizedAffiliateUrl);
  assert(synthesizedAffiliateUrl.startsWith('https://rdr.btrck.com/aff_c'), 'Must start with rdr.btrck.com/aff_c');
  assert(synthesizedAffiliateUrl.includes('offer_id=5'), 'offer_id must be 5');
  assert(synthesizedAffiliateUrl.includes('aff_id=1016'), 'aff_id must be 1016');
  assert(synthesizedAffiliateUrl.includes(`source=${adminUserId}`), 'source must match admin UUID');
  assert(synthesizedAffiliateUrl.includes(`aff_sub=${adminUserId}`), 'aff_sub must match admin UUID');
  // Teknosa yerel Paylaş Kazan yönlendirmesiyle uyumlu düz slash standardı:
  assert(synthesizedAffiliateUrl.includes('aff_sub3=teknosa.com/yenilenmis-iphone-xr-128-gb-mavi-cep-telefonu-1-yil-garantili-a-kalite-p-790182989'), 'aff_sub3 must use plain slash standard');
  assert(!synthesizedAffiliateUrl.includes('aff_sub3=teknosa.com%2F'), 'aff_sub3 must NOT contain encoded slash');
  const parsedTune = new URL(synthesizedAffiliateUrl);
  const targetUrlParam = parsedTune.searchParams.get('url');
  assert(targetUrlParam && targetUrlParam.includes('shopId=2442'), 'shopId seller parameter must be preserved in url parameter');
  assert(targetUrlParam && targetUrlParam.includes('utm_source=social_affiliate'), 'utm_source must be social_affiliate');
  assert(targetUrlParam && targetUrlParam.includes('utm_medium=paylaskazan'), 'utm_medium must be paylaskazan');
  assert(targetUrlParam && targetUrlParam.includes(`utm_campaign=${adminUserId}`), 'utm_campaign must contain admin UUID');
  console.log('✅ Test 2 Passed: affiliateManager.convert eksiksiz TUNE deep-link üretti.\n');

  // Test 3: affiliateManager.isAlreadyAffiliate verification
  console.log('Test 3: affiliateManager.isAlreadyAffiliate verification');
  assert(affiliateManager.isAlreadyAffiliate(synthesizedAffiliateUrl, adminUserId), 'Our TUNE link must be recognized as already affiliate');
  assert(!affiliateManager.isAlreadyAffiliate(canonicalProductUrl), 'Canonical URL must NOT be recognized as affiliate');
  assert(!affiliateManager.isAlreadyAffiliate('https://paylaskazan.teknosa.com/teknosa-F8NSB38NC3'), 'Shortlink must NOT be recognized as affiliate');

  const competitorUrl = 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=11111111-2222-3333-4444-555555555555&aff_sub=11111111-2222-3333-4444-555555555555&aff_sub3=teknosa.com/test-p-123&url=https%3A%2F%2Fwww.teknosa.com%2Ftest-p-123';
  assert(!affiliateManager.isAlreadyAffiliate(competitorUrl, adminUserId), 'Competitor TUNE link must NOT be recognized as our affiliate');

  const legacyEncodedUrl = `https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=${adminUserId}&aff_sub=${adminUserId}&aff_sub3=teknosa.com%2Ftest-p-123&url=https%3A%2F%2Fwww.teknosa.com%2Ftest-p-123`;
  assert(!affiliateManager.isAlreadyAffiliate(legacyEncodedUrl, adminUserId), 'Legacy %2F link must NOT be recognized as finalized affiliate (to trigger auto-upgrade)');
  console.log('✅ Test 3 Passed: isAlreadyAffiliate yetkilendirmesi ve legacy tespiti kusursuz çalışıyor.\n');

  // Test 4: Anti-Hijacking and Retargeting Competitor TUNE Link to Admin UUID
  console.log('Test 4: Anti-Hijacking and Retargeting Competitor TUNE Link to Admin UUID');
  const retargetedUrl = affiliateManager.convert(competitorUrl, {
    teknosaAffiliateEnabled: true,
    teknosaUserId: adminUserId
  });
  console.log('Retargeted URL:\n  ', retargetedUrl);
  assert(retargetedUrl.includes(`source=${adminUserId}`), 'Must be retargeted to admin UUID');
  assert(retargetedUrl.includes(`aff_sub=${adminUserId}`), 'aff_sub must be retargeted to admin UUID');
  assert(!retargetedUrl.includes('11111111-2222-3333-4444-555555555555'), 'Competitor UUID MUST be completely removed');
  console.log('✅ Test 4 Passed: Rakip TUNE linki admin hesabına (anti-hijack) dönüştürüldü.\n');

  // Test 5: Auto-upgrade legacy %2F btrck link to plain slash standard
  console.log('Test 5: Auto-upgrade legacy %2F btrck link to plain slash standard');
  const upgradedUrl = affiliateManager.convert(legacyEncodedUrl, {
    teknosaAffiliateEnabled: true,
    teknosaUserId: adminUserId
  });
  console.log('Upgraded URL:\n  ', upgradedUrl);
  assert(upgradedUrl.includes('aff_sub3=teknosa.com/test-p-123'), 'Must be upgraded to plain slash');
  assert(!upgradedUrl.includes('aff_sub3=teknosa.com%2F'), 'Encoded slash must be eliminated');
  console.log('✅ Test 5 Passed: Eski %2F btrck linki düz slash standardına yükseltildi.\n');

  // Test 6: Kill-Switch / Fallback when teknosaAffiliateEnabled is false
  console.log('Test 6: Kill-Switch / Fallback when teknosaAffiliateEnabled is false');
  const fallbackFromCompetitor = affiliateManager.convert(competitorUrl, {
    teknosaAffiliateEnabled: false
  });
  console.log('Fallback from competitor:\n  ', fallbackFromCompetitor);
  assert(!fallbackFromCompetitor.includes('btrck.com'), 'Must not contain btrck.com when disabled');
  assert(fallbackFromCompetitor.includes('teknosa.com'), 'Must fallback to teknosa.com');
  assert(!fallbackFromCompetitor.includes('11111111-2222-3333-4444-555555555555'), 'Must strip competitor tracking');
  assert(!fallbackFromCompetitor.includes('utm_source'), 'Must strip UTMs');
  console.log('✅ Test 6 Passed: Kill-switch kapalıyken tertemiz organik Teknosa linkine unwrap edildi.\n');

  // Test 7: cleanProductUrl verification
  console.log('Test 7: cleanProductUrl verification');
  const cleanFromSynthesized = affiliateManager.cleanProductUrl(synthesizedAffiliateUrl);
  console.log('Clean from synthesized:\n  ', cleanFromSynthesized);
  assert(cleanFromSynthesized.includes('teknosa.com'), 'Clean URL must be teknosa.com');
  assert(!cleanFromSynthesized.includes('btrck.com'), 'Clean URL must not be btrck.com');
  assert(cleanFromSynthesized.includes('shopId=2442'), 'Clean URL preserves seller shopId parameter');
  assert(!cleanFromSynthesized.includes('utm_source'), 'Clean URL must strip UTMs');

  const cleanFromLegacy = affiliateManager.cleanProductUrl(legacyEncodedUrl);
  assert(cleanFromLegacy.includes('teknosa.com/test-p-123'), 'Clean URL unwrapped from aff_sub3 correctly');
  console.log('✅ Test 7 Passed: cleanProductUrl temiz ürün linkini kusursuz çıkardı.\n');

  // Test 8: Live resolution of user paylaskazan.teknosa.com shortlink
  console.log('Test 8: Testing live resolution of user paylaskazan.teknosa.com shortlink via linkScraperService');
  const paylasKazanUrl = 'https://paylaskazan.teknosa.com/teknosa-F8NSB38NC3';
  const resolved = await linkScraperService.resolveUrlRedirects(paylasKazanUrl);
  console.log(`  -> Resolved: ${resolved}`);
  assert(resolved.includes('teknosa.com'), 'Must resolve to teknosa.com');
  assert(resolved.includes('-p-790182989'), 'Must contain product ID');
  assert(resolved.includes('shopId=2442'), 'Must preserve shopId');
  console.log('✅ Test 8 Passed: Paylaş Kazan kısa linki başarıyla kanonik linke çözümlendi.\n');

  console.log('🎉 All Node.js Teknosa Paylaş Kazan (TUNE HasOffers) Affiliate Tests Passed Successfully!');
}

runTests().catch(err => {
  console.error('❌ Test Failed:', err);
  process.exit(1);
});
