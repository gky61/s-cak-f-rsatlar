const assert = require('assert');
const affiliateManager = require('../affiliate_manager');
const linkScraperService = require('../link_scraper_service');

async function runPipelineTests() {
  console.log('=== Telegram Bot Node Scraper Affiliate Ingestion Pipeline Tests ===\n');

  // Test 1: Live resolution of user/telegram amzn.eu shortlinks
  console.log('Test 1: Resolving Telegram amzn.eu mobile share shortlink...');
  const testShortLink = 'https://amzn.eu/d/097K8DSA';
  const resolved = await linkScraperService.resolveUrlRedirects(testShortLink);
  console.log(`  -> Shortlink: ${testShortLink}`);
  console.log(`  -> Resolved:  ${resolved}`);
  assert(resolved.includes('amazon.com.tr'), 'Resolved URL must point to amazon.com.tr');
  assert(resolved.includes('/dp/') || resolved.includes('ASIN='), 'Resolved URL must contain product identifier');
  console.log('✅ Test 1 Passed: Telegram amzn.eu kısa linki başarıyla çözüldü.\n');

  // Test 2: Ingestion & Anti-Hijacking of Competitor Affiliate Link from Telegram
  console.log('Test 2: Anti-Hijacking and Retargeting Competitor Telegram Post to firsatkolik-21...');
  const competitorTelegramUrl = 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=rakipaffiliate-21&linkCode=ll1&ref_=cm_sw_r_apan_dp_123&ascsubtag=customtracker';
  
  // 2a: Test cleanProductUrl (Clean store URL for users)
  const cleanUrl = affiliateManager.cleanProductUrl(competitorTelegramUrl);
  console.log(`  -> Input:    ${competitorTelegramUrl}`);
  console.log(`  -> Clean:    ${cleanUrl}`);
  assert.strictEqual(cleanUrl, 'https://www.amazon.com.tr/dp/B08N5WRWNW', 'cleanProductUrl must strip all query parameters for Amazon');
  console.log('✅ Test 2a Passed: cleanProductUrl organik kanonik linki tertemiz üretti.\n');

  // 2b: Test affiliate conversion with anti-hijack
  const convertedDealLink = affiliateManager.convert(competitorTelegramUrl, {
    amazonAffiliateEnabled: true,
    amazonAffiliateTag: 'firsatkolik-21'
  });
  console.log(`  -> Converted Deal Link: ${convertedDealLink}`);
  assert(convertedDealLink.includes('amazon.com.tr/dp/B08N5WRWNW'), 'Must preserve canonical product ASIN');
  assert(convertedDealLink.includes('tag=firsatkolik-21'), 'Must inject official tracking ID firsatkolik-21');
  assert(!convertedDealLink.includes('rakipaffiliate-21'), 'Competitor tag MUST be removed');
  assert(!convertedDealLink.includes('linkCode'), 'linkCode garbage MUST be removed');
  assert(!convertedDealLink.includes('ascsubtag'), 'ascsubtag garbage MUST be removed');
  assert(!convertedDealLink.includes('ref_'), 'ref_ parameter MUST be removed');
  console.log('✅ Test 2b Passed: Rakip takip tag\'i başarıyla ezildi ve firsatkolik-21 enjekte edildi.\n');

  // Test 3: isAlreadyAffiliate verification
  console.log('Test 3: Validating isAlreadyAffiliate state...');
  const ourAffiliateUrl = 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=firsatkolik-21';
  assert(affiliateManager.isAlreadyAffiliate(ourAffiliateUrl), 'Our tag must be recognized as already affiliate');
  assert(!affiliateManager.isAlreadyAffiliate(competitorTelegramUrl), 'Competitor tag must NOT be recognized as already affiliate');
  assert(!affiliateManager.isAlreadyAffiliate('https://amzn.eu/d/097K8DSA'), 'Shortlink must NOT be recognized as already affiliate');
  console.log('✅ Test 3 Passed: isAlreadyAffiliate sadece ve sadece kendi tag\'imizi doğruluyor.\n');

  // Test 4: Kill-Switch / Fallback when amazonAffiliateEnabled is false
  console.log('Test 4: Kill-Switch / Fallback unwrap behavior...');
  const disabledSettings = { amazonAffiliateEnabled: false };
  const fallbackUrl = affiliateManager.convert(competitorTelegramUrl, disabledSettings);
  console.log(`  -> Fallback URL when disabled: ${fallbackUrl}`);
  assert.strictEqual(fallbackUrl, 'https://www.amazon.com.tr/dp/B08N5WRWNW', 'When disabled, fallback must return clean canonical product URL without any tags');
  console.log('✅ Test 4 Passed: Kill-switch kapalıyken tertemiz organik linke fallback yapıldı.\n');

  // Test 5: End-to-End Deal Object Validation (Simulating telegram_bot.js saveDealToFirebase)
  console.log('Test 5: Simulating saveDealToFirebase deal creation with competitor Amazon URL...');
  const rawTargetUrl = competitorTelegramUrl;
  const simulatedAppSettings = {
    dealApprovalRequired: false,
    amazonAffiliateEnabled: true,
    amazonAffiliateTag: 'firsatkolik-21'
  };

  const finalCleanUrl = affiliateManager.cleanProductUrl(rawTargetUrl);
  const finalDealLink = affiliateManager.convert(rawTargetUrl, simulatedAppSettings);

  const simulatedDeal = {
    title: 'Apple MacBook Air M1 8GB 256GB SSD',
    link: finalDealLink,
    cleanUrl: finalCleanUrl,
    store: 'Amazon',
    isApproved: !simulatedAppSettings.dealApprovalRequired
  };

  console.log('  -> Simulated Firestore Deal:');
  console.log(`     deal.cleanUrl:   ${simulatedDeal.cleanUrl}`);
  console.log(`     deal.link:       ${simulatedDeal.link}`);
  console.log(`     deal.isApproved: ${simulatedDeal.isApproved}`);

  assert.strictEqual(simulatedDeal.cleanUrl, 'https://www.amazon.com.tr/dp/B08N5WRWNW');
  assert.strictEqual(simulatedDeal.link, 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=firsatkolik-21');
  assert.strictEqual(simulatedDeal.isApproved, true);
  console.log('✅ Test 5 Passed: Telegram botu Firestore belgesini sıfır hata ile üretti!\n');

  // Test 7: Live resolution of Telegram Hepsiburada app.hb.biz shortlinks
  console.log('Test 7: Resolving Telegram app.hb.biz mobile share shortlink...');
  const testHbShortLink = 'https://app.hb.biz/xh5GZgJFADek';
  const resolvedHb = await linkScraperService.resolveUrlRedirects(testHbShortLink);
  console.log(`  -> Shortlink: ${testHbShortLink}`);
  console.log(`  -> Resolved:  ${resolvedHb}`);
  assert(resolvedHb.includes('hepsiburada.com'), 'Resolved URL must point to hepsiburada.com');
  assert(resolvedHb.includes('-p-') || resolvedHb.includes('HBCV'), 'Resolved URL must contain product identifier');
  console.log('✅ Test 7 Passed: Telegram app.hb.biz kısa linki başarıyla çözüldü.\n');

  // Test 8: Ingestion & Anti-Hijacking of Competitor Hepsiburada Adjust Link from Telegram
  console.log('Test 8: Anti-Hijacking and Retargeting Competitor Telegram Hepsiburada Link to muratcan gokyokus...');
  const competitorHbUrl = 'https://7t4g.adj.st/product?sku=HBCV000003LVO6&adj_t=10zuiki3_y4q2fze&adj_adgroup=rakip_influencer&adj_fallback=' +
    encodeURIComponent('https://www.hepsiburada.com/altinyildiz-classics-erkek-100-pamuk-v-yaka-lacivert-slim-fit-duz-t-shirt-p-HBCV000003LVO6?magaza=Alt%C4%B1ny%C4%B1ld%C4%B1z%20Classics');

  // 8a: Test cleanProductUrl (Clean store URL for users)
  const cleanHbUrl = affiliateManager.cleanProductUrl(competitorHbUrl);
  console.log(`  -> Input:    ${competitorHbUrl}`);
  console.log(`  -> Clean:    ${cleanHbUrl}`);
  assert(cleanHbUrl.includes('hepsiburada.com/altinyildiz-classics-erkek-100-pamuk-v-yaka-lacivert-slim-fit-duz-t-shirt-p-HBCV000003LVO6'), 'cleanProductUrl must extract clean canonical URL');
  assert(!cleanHbUrl.includes('7t4g.adj.st'), 'cleanProductUrl must NOT be an Adjust link');
  assert(!cleanHbUrl.includes('rakip_influencer'), 'cleanProductUrl must not contain competitor');
  console.log('✅ Test 8a Passed: cleanProductUrl Hepsiburada için organik kanonik linki tertemiz üretti.\n');

  // 8b: Test affiliate conversion with anti-hijack
  const convertedHbDealLink = affiliateManager.convert(competitorHbUrl, {
    hepsiburadaAffiliateEnabled: true,
    hepsiburadaAccountName: 'muratcan gokyokus'
  });
  console.log(`  -> Converted Deal Link: ${convertedHbDealLink}`);
  assert(convertedHbDealLink.startsWith('https://7t4g.adj.st/product'), 'Must be 7t4g.adj.st Adjust link');
  assert(convertedHbDealLink.includes('adj_adgroup=muratcan%20gokyokus') || convertedHbDealLink.includes('adj_adgroup=muratcan+gokyokus'), 'Must inject official account muratcan gokyokus');
  assert(!convertedHbDealLink.includes('rakip_influencer'), 'Competitor account MUST be purged');
  assert(convertedHbDealLink.includes('sku=HBCV000003LVO6'), 'SKU must be preserved');
  console.log('✅ Test 8b Passed: Rakip Hepsiburada Adjust linki başarıyla ezildi ve muratcan gokyokus enjekte edildi.\n');

  // Test 9: isAlreadyAffiliate and Kill-Switch verification for Hepsiburada
  console.log('Test 9: Validating Hepsiburada isAlreadyAffiliate and Kill-Switch states...');
  assert(affiliateManager.isAlreadyAffiliate(convertedHbDealLink, 'muratcan gokyokus'), 'Our account must be recognized as already affiliate');
  assert(!affiliateManager.isAlreadyAffiliate(competitorHbUrl, 'muratcan gokyokus'), 'Competitor account must NOT be recognized as already affiliate');
  assert(!affiliateManager.isAlreadyAffiliate(testHbShortLink), 'Shortlink must NOT be recognized as already affiliate');

  const disabledHbSettings = { hepsiburadaAffiliateEnabled: false };
  const fallbackHbUrl = affiliateManager.convert(competitorHbUrl, disabledHbSettings);
  console.log(`  -> Fallback URL when disabled: ${fallbackHbUrl}`);
  assert(!fallbackHbUrl.includes('7t4g.adj.st'), 'When disabled, fallback must not be Adjust URL');
  assert(fallbackHbUrl.includes('hepsiburada.com'), 'When disabled, fallback must return canonical hepsiburada.com URL');
  console.log('✅ Test 9 Passed: Hepsiburada yetkilendirme ve kill-switch fallback testleri başarılı.\n');

  // Test 10: End-to-End Deal Object Validation (Simulating telegram_bot.js saveDealToFirebase for Hepsiburada)
  console.log('Test 10: Simulating saveDealToFirebase deal creation with competitor Hepsiburada URL...');
  const simulatedHbAppSettings = {
    dealApprovalRequired: false,
    hepsiburadaAffiliateEnabled: true,
    hepsiburadaAccountName: 'muratcan gokyokus'
  };

  const finalHbCleanUrl = affiliateManager.cleanProductUrl(competitorHbUrl);
  const finalHbDealLink = affiliateManager.convert(competitorHbUrl, simulatedHbAppSettings);

  const simulatedHbDeal = {
    title: 'Altınyıldız Classics Erkek %100 Pamuk V Yaka T-Shirt',
    link: finalHbDealLink,
    cleanUrl: finalHbCleanUrl,
    store: 'Hepsiburada',
    isApproved: !simulatedHbAppSettings.dealApprovalRequired
  };

  console.log('  -> Simulated Firestore Deal:');
  console.log(`     deal.cleanUrl:   ${simulatedHbDeal.cleanUrl}`);
  console.log(`     deal.link:       ${simulatedHbDeal.link}`);
  console.log(`     deal.isApproved: ${simulatedHbDeal.isApproved}`);

  assert(simulatedHbDeal.cleanUrl.includes('hepsiburada.com'));
  assert(!simulatedHbDeal.cleanUrl.includes('7t4g.adj.st'));
  assert(simulatedHbDeal.link.includes('7t4g.adj.st'));
  assert(simulatedHbDeal.link.includes('adj_adgroup=muratcan%20gokyokus') || simulatedHbDeal.link.includes('adj_adgroup=muratcan+gokyokus'));
  assert.strictEqual(simulatedHbDeal.isApproved, true);
  console.log('✅ Test 10 Passed: Telegram botu Hepsiburada için Firestore belgesini sıfır hata ile üretti!\n');

  // Test 11: Live resolution of Telegram Teknosa paylaskazan.teknosa.com shortlinks
  console.log('Test 11: Resolving Telegram paylaskazan.teknosa.com mobile share shortlink...');
  const testTeknosaShortLink = 'https://paylaskazan.teknosa.com/teknosa-F8NSB38NC3';
  const resolvedTeknosa = await linkScraperService.resolveUrlRedirects(testTeknosaShortLink);
  console.log(`  -> Shortlink: ${testTeknosaShortLink}`);
  console.log(`  -> Resolved:  ${resolvedTeknosa}`);
  assert(resolvedTeknosa.includes('teknosa.com'), 'Resolved URL must point to teknosa.com');
  assert(resolvedTeknosa.includes('-p-790182989'), 'Resolved URL must contain product identifier');
  assert(resolvedTeknosa.includes('shopId=2442'), 'Resolved URL must preserve seller shopId');
  console.log('✅ Test 11 Passed: Telegram paylaskazan.teknosa.com kısa linki başarıyla çözüldü.\n');

  // Test 12: Ingestion & Anti-Hijacking of Competitor Teknosa TUNE Link from Telegram
  console.log('Test 12: Anti-Hijacking and Retargeting Competitor Telegram Teknosa Link to 906bd201-92dc-4898-914a-10309b2cd576...');
  const competitorTeknosaUrl = 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=11111111-2222-3333-4444-555555555555&aff_sub=11111111-2222-3333-4444-555555555555&aff_sub3=teknosa.com/yenilenmis-iphone-xr-128-gb-mavi-cep-telefonu-1-yil-garantili-a-kalite-p-790182989&url=' +
    encodeURIComponent('https://www.teknosa.com/yenilenmis-iphone-xr-128-gb-mavi-cep-telefonu-1-yil-garantili-a-kalite-p-790182989?shopId=2442&utm_source=social_affiliate&utm_medium=paylaskazan&utm_campaign=11111111-2222-3333-4444-555555555555');

  // 12a: Test cleanProductUrl (Clean store URL for users)
  const cleanTeknosaUrl = affiliateManager.cleanProductUrl(competitorTeknosaUrl);
  console.log(`  -> Input:    ${competitorTeknosaUrl}`);
  console.log(`  -> Clean:    ${cleanTeknosaUrl}`);
  assert(cleanTeknosaUrl.includes('teknosa.com/yenilenmis-iphone-xr-128-gb-mavi-cep-telefonu-1-yil-garantili-a-kalite-p-790182989'), 'cleanProductUrl must extract clean canonical URL');
  assert(cleanTeknosaUrl.includes('shopId=2442'), 'cleanProductUrl must preserve seller shopId');
  assert(!cleanTeknosaUrl.includes('btrck.com'), 'cleanProductUrl must NOT be a TUNE link');
  assert(!cleanTeknosaUrl.includes('11111111-2222-3333-4444-555555555555'), 'cleanProductUrl must not contain competitor');
  assert(!cleanTeknosaUrl.includes('utm_source'), 'cleanProductUrl must strip tracking');
  console.log('✅ Test 12a Passed: cleanProductUrl Teknosa için organik kanonik linki tertemiz üretti.\n');

  // 12b: Test affiliate conversion with anti-hijack
  const convertedTeknosaDealLink = affiliateManager.convert(competitorTeknosaUrl, {
    teknosaAffiliateEnabled: true,
    teknosaUserId: '906bd201-92dc-4898-914a-10309b2cd576'
  });
  console.log(`  -> Converted Deal Link: ${convertedTeknosaDealLink}`);
  assert(convertedTeknosaDealLink.startsWith('https://rdr.btrck.com/aff_c'), 'Must be rdr.btrck.com TUNE link');
  assert(convertedTeknosaDealLink.includes('source=906bd201-92dc-4898-914a-10309b2cd576'), 'Must inject official UUID 906bd201-92dc-4898-914a-10309b2cd576');
  assert(convertedTeknosaDealLink.includes('aff_sub=906bd201-92dc-4898-914a-10309b2cd576'), 'Must inject official UUID into aff_sub');
  assert(!convertedTeknosaDealLink.includes('11111111-2222-3333-4444-555555555555'), 'Competitor UUID MUST be purged');
  assert(convertedTeknosaDealLink.includes('aff_sub3=teknosa.com/yenilenmis-iphone-xr'), 'Plain slash standard must be used');
  assert(!convertedTeknosaDealLink.includes('aff_sub3=teknosa.com%2F'), 'Encoded slash must not be present');
  console.log('✅ Test 12b Passed: Rakip Teknosa TUNE linki başarıyla ezildi ve 906bd201-92dc-4898-914a-10309b2cd576 enjekte edildi.\n');

  // Test 13: isAlreadyAffiliate and Kill-Switch verification for Teknosa
  console.log('Test 13: Validating Teknosa isAlreadyAffiliate and Kill-Switch states...');
  assert(affiliateManager.isAlreadyAffiliate(convertedTeknosaDealLink, '906bd201-92dc-4898-914a-10309b2cd576'), 'Our account must be recognized as already affiliate');
  assert(!affiliateManager.isAlreadyAffiliate(competitorTeknosaUrl, '906bd201-92dc-4898-914a-10309b2cd576'), 'Competitor account must NOT be recognized as already affiliate');
  assert(!affiliateManager.isAlreadyAffiliate(testTeknosaShortLink), 'Shortlink must NOT be recognized as already affiliate');

  const disabledTeknosaSettings = { teknosaAffiliateEnabled: false };
  const fallbackTeknosaUrl = affiliateManager.convert(competitorTeknosaUrl, disabledTeknosaSettings);
  console.log(`  -> Fallback URL when disabled: ${fallbackTeknosaUrl}`);
  assert(!fallbackTeknosaUrl.includes('btrck.com'), 'When disabled, fallback must not be TUNE URL');
  assert(fallbackTeknosaUrl.includes('teknosa.com'), 'When disabled, fallback must return canonical teknosa.com URL');
  console.log('✅ Test 13 Passed: Teknosa yetkilendirme ve kill-switch fallback testleri başarılı.\n');

  // Test 14: End-to-End Deal Object Validation (Simulating telegram_bot.js saveDealToFirebase for Teknosa)
  console.log('Test 14: Simulating saveDealToFirebase deal creation with competitor Teknosa URL...');
  const simulatedTeknosaAppSettings = {
    dealApprovalRequired: false,
    teknosaAffiliateEnabled: true,
    teknosaUserId: '906bd201-92dc-4898-914a-10309b2cd576'
  };

  const finalTeknosaCleanUrl = affiliateManager.cleanProductUrl(competitorTeknosaUrl);
  const finalTeknosaDealLink = affiliateManager.convert(competitorTeknosaUrl, simulatedTeknosaAppSettings);

  const simulatedTeknosaDeal = {
    title: 'Yenilenmiş iPhone XR 128 GB Mavi Cep Telefonu 1 Yıl Garantili A Kalite',
    link: finalTeknosaDealLink,
    cleanUrl: finalTeknosaCleanUrl,
    store: 'Teknosa',
    isApproved: !simulatedTeknosaAppSettings.dealApprovalRequired
  };

  console.log('  -> Simulated Firestore Deal:');
  console.log(`     deal.cleanUrl:   ${simulatedTeknosaDeal.cleanUrl}`);
  console.log(`     deal.link:       ${simulatedTeknosaDeal.link}`);
  console.log(`     deal.isApproved: ${simulatedTeknosaDeal.isApproved}`);

  assert(simulatedTeknosaDeal.cleanUrl.includes('teknosa.com'));
  assert(simulatedTeknosaDeal.cleanUrl.includes('shopId=2442'));
  assert(!simulatedTeknosaDeal.cleanUrl.includes('btrck.com'));
  assert(simulatedTeknosaDeal.link.includes('rdr.btrck.com'));
  assert(simulatedTeknosaDeal.link.includes('source=906bd201-92dc-4898-914a-10309b2cd576'));
  assert.strictEqual(simulatedTeknosaDeal.isApproved, true);
  console.log('✅ Test 14 Passed: Telegram botu Teknosa için Firestore belgesini sıfır hata ile üretti!\n');

  console.log('🎉🎉🎉 ALL TELEGRAM BOT AFFILIATE INGESTION PIPELINE TESTS PASSED! 🎉🎉🎉');
}

runPipelineTests().catch(err => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
