/**
 * FırsatKolik — Çift Kademeli Mükerrerlik ve Gerçek Fiyat Doğrulama Testi
 * 
 * Bu test, 4 adet ikiz ürünün (Haluk Aydın Kuruyemiş vakası) admin onay kuyruğunu
 * şişirmesini kökten engelleyen 2 kuralı doğrular:
 * 1. Onay Bekleyen (Pending) Fırsat Kalkanı
 * 2. Kazıma Sonrası (Post-Scrape) Gerçek Fiyat Doğrulama Kalkanı
 */

const assert = require('assert');

// telegram_bot.js içindeki extractPrice fonksiyonu
function extractPrice(text) {
  if (!text) return null;
  const pricePatterns = [
    /(\d+(?:\.\d{3})+(?:,\d{2})?)\s*(?:TL|₺|Lira)/gi,
    /(\d+(?:,\d{2})?)\s*(?:TL|₺|Lira)/gi,
    /(?:TL|₺)\s*(\d+(?:\.\d{3})+(?:,\d{2})?)/gi,
    /(?:TL|₺)\s*(\d+(?:,\d{2})?)/gi,
    /(?:fiyat|fiyatı|fiyat bilgisi)\s*(?:bilgisi)?\s*(?::|is|=)?\s*(\d+(?:\.\d{3})*(?:,\d{2})?)/gi
  ];
  for (const pattern of pricePatterns) {
    const match = text.match(pattern);
    if (match) {
      pattern.lastIndex = 0;
      const cleanMatch = pattern.exec(text);
      let cleanNum = cleanMatch && cleanMatch[1] ? cleanMatch[1] : match[0].replace(/[^\d,.]/g, '');
      pattern.lastIndex = 0;
      if (cleanNum.includes('.') && cleanNum.includes(',')) cleanNum = cleanNum.replace(/\./g, '').replace(',', '.');
      else if (cleanNum.includes(',')) cleanNum = cleanNum.replace(',', '.');
      const parsed = parseFloat(cleanNum);
      if (!isNaN(parsed)) return parsed;
    }
  }
  return null;
}

// Pre-scrape mantığı
function evaluatePreScrape(existingDocs, messageText) {
  const now = new Date();
  const messagePrice = extractPrice(messageText);

  for (const dealData of existingDocs) {
    if (dealData.isRejected === true || dealData.status === 'rejected') continue;
    const dealCreatedAt = dealData.createdAt ? (dealData.createdAt.toDate ? dealData.createdAt.toDate() : dealData.createdAt) : new Date();
    if ((now - dealCreatedAt) > (48 * 60 * 60 * 1000)) continue;
    if (dealData.isExpired === true || dealData.status === 'expired') continue;

    // 🛡️ KURAL 1: Onay Bekleyen (Pending) Fırsat Kalkanı:
    if (dealData.isApproved === false) {
      return { isDuplicate: true, reason: 'pending_in_queue' };
    }

    // 5. Fiyat Düşüşü Toleransı (Yalnızca onaylılar için):
    const existingPrice = Number(dealData.price) || 0;
    if (messagePrice && messagePrice > 0 && existingPrice > 0 && messagePrice <= (existingPrice * 0.95)) {
      return { isDuplicate: false, allowedByPriceDrop: true };
    }

    return { isDuplicate: true, reason: 'active_duplicate' };
  }
  return { isDuplicate: false, isNew: true };
}

// Post-scrape mantığı
function evaluatePostScrape(existingDocs, finalPrice, currentDocId) {
  for (const existingDeal of existingDocs) {
    if (existingDeal.id === currentDocId) continue;
    if (existingDeal.isRejected === true || existingDeal.status === 'rejected') continue;
    if (existingDeal.isExpired === true || existingDeal.status === 'expired') continue;

    // A) Onay bekleyen kontrolü
    if (existingDeal.isApproved === false) {
      return { canSave: false, reason: 'pending_in_queue' };
    }

    // B) Onaylı fırsat için gerçek fiyat düşüşü kontrolü
    const existingPrice = Number(existingDeal.price) || 0;
    if (finalPrice > 0 && existingPrice > 0 && finalPrice <= (existingPrice * 0.95)) {
      continue; // gerçek fiyat düşüşü var
    } else {
      return { canSave: false, reason: 'fake_price_drop' };
    }
  }
  return { canSave: true };
}

async function runTests() {
  console.log('🧪 Başlatılıyor: Çift Kademeli Mükerrerlik Koruma Testleri...');

  // TEST 1: Haluk Aydın Kuruyemiş Canlı Vakası (4 Gelen Mesaj)
  console.log('\n--- Test 1: Haluk Aydın Kuruyemiş 4 Farklı Kanal Vakası ---');
  const database = [];

  const rawMessages = [
    { id: 'telegram_1622720156_13690', text: 'Haluk Aydın Kuruyemiş 1000 gr 🏷️ 619 TL MARKETİM200 Kodunu kullanın' },
    { id: 'telegram_2343434094_3461', text: 'Haluk Aydın Kuruyemiş 1000 gr ✅ 619 TL MARKETİM200 kuponu sepette uygula' },
    { id: 'telegram_1245519625_113611', text: '🔥Haluk Aydın 1kg Fındık İçi MARKETİM200 Kodu ile 619TL' },
    { id: 'telegram_1457742945_89109', text: '🔥Haluk Aydın 1kg Fındık İçi MARKETİM200 Kodu ile 619TL' }
  ];

  for (let i = 0; i < rawMessages.length; i++) {
    const msg = rawMessages[i];
    const preResult = evaluatePreScrape(database, msg.text);

    if (i === 0) {
      assert.strictEqual(preResult.isDuplicate, false, 'İlk mesaj mükerrer olmamalı');
      // İlk mesaj kazındı, sayfadan 819 TL geldi ve onay bekliyor olarak kaydedildi
      const postResult = evaluatePostScrape(database, 819, msg.id);
      assert.strictEqual(postResult.canSave, true, 'İlk mesaj kaydedilebilmeli');
      database.push({
        id: msg.id,
        price: 819,
        isApproved: false,
        createdAt: new Date()
      });
    } else {
      // 2., 3. ve 4. mesajlar Kural 1 (Onay Bekleyen Kalkanı) sayesinde pre-scrape aşamasında engellenmeli!
      assert.strictEqual(preResult.isDuplicate, true, `Mesaj #${i + 1} mükerrer olarak engellenmeli`);
      assert.strictEqual(preResult.reason, 'pending_in_queue');
    }
  }

  assert.strictEqual(database.length, 1, 'Admin onay kuyruğunda SADECE 1 ADET ürün olmalı!');
  console.log('✅ Test 1 Başarılı: 4 mesajdan yalnızca 1 tanesi admin onayına düştü, 3 mükerrer engellendi!');

  // TEST 2: Onaylı Ürün Varken Kuponlu Mesaj Fiyat Aldatmacası
  console.log('\n--- Test 2: Onaylı Ürün Varken Sayfada Düşmeyen Fiyat (Post-Scrape Kalkanı) ---');
  const liveApprovedDeals = [
    {
      id: 'active_deal_1',
      price: 819,
      isApproved: true, // Canlıda onaylı
      createdAt: new Date()
    }
  ];

  // Kanal "Kuponla 619 TL" diyor
  const preCheck2 = evaluatePreScrape(liveApprovedDeals, 'Haluk Aydın 619 TL kupon kodu ile');
  assert.strictEqual(preCheck2.isDuplicate, false, 'Pre-scrape potansiyel indirim için kazımaya izin vermeli');

  // Sayfadan liste fiyatı 819 TL geldi (fiyat aslında düşmemiş!)
  const postCheck2 = evaluatePostScrape(liveApprovedDeals, 819, 'new_deal');
  assert.strictEqual(postCheck2.canSave, false, 'Sayfadaki fiyat düşmediği için kayıt iptal edilmeli');
  assert.strictEqual(postCheck2.reason, 'fake_price_drop');
  console.log('✅ Test 2 Başarılı: Post-scrape kapısı sahte/kuponlu fiyat aldatmacasını yakaladı ve engelledi!');

  // TEST 3: Gerçek Fiyat Düşüşü (Örnek: 1.000 TL -> 500 TL)
  console.log('\n--- Test 3: Canlıdaki Üründe Gerçek %50 Fiyat Düşüşü ---');
  const liveDeals3 = [
    {
      id: 'active_deal_headphones',
      price: 1000,
      isApproved: true,
      createdAt: new Date()
    }
  ];

  // Kanal "Büyük İndirim 500 TL" diyor
  const preCheck3 = evaluatePreScrape(liveDeals3, 'Kulaklık Süper Fiyat 500 TL');
  assert.strictEqual(preCheck3.isDuplicate, false, 'Pre-scrape kazımaya izin vermeli');

  // Sayfadan gerçekten 500 TL geldi!
  const postCheck3 = evaluatePostScrape(liveDeals3, 500, 'new_deal_headphones');
  assert.strictEqual(postCheck3.canSave, true, 'Gerçek fiyat düşüşü onaylanıp kaydedilmeli');
  console.log('✅ Test 3 Başarılı: Gerçek fiyat düşüşü kaçırılmadı, başarıyla onaylandı!');

  // TEST 4: Hepsiburada Varyant vs Ana Model Vakası (DeFacto Mont Canlı Vakası)
  console.log('\n--- Test 4: Hepsiburada Varyant vs Ana Model Vakası (DeFacto Mont) ---');
  const affiliateManager = require('../affiliate_manager');
  
  function buildCanonicalCleanUrl(rawTargetUrl, canonicalUrl) {
    if (!rawTargetUrl) return '';
    if (!canonicalUrl || typeof canonicalUrl !== 'string' || !canonicalUrl.trim()) {
      return affiliateManager.cleanProductUrl(rawTargetUrl);
    }
    try {
      const rawObj = new URL(rawTargetUrl.trim());
      const canonObj = new URL(canonicalUrl.trim());
      const rawHost = rawObj.hostname.replace(/^www\./, '').toLowerCase();
      const canonHost = canonObj.hostname.replace(/^www\./, '').toLowerCase();
      if (!rawHost.endsWith(canonHost) && !canonHost.endsWith(rawHost)) {
        return affiliateManager.cleanProductUrl(rawTargetUrl);
      }
      if (rawObj.searchParams.has('magaza') && !canonObj.searchParams.has('magaza')) {
        canonObj.searchParams.set('magaza', rawObj.searchParams.get('magaza'));
      }
      if (rawObj.searchParams.has('shopId') && !canonObj.searchParams.has('shopId')) {
        canonObj.searchParams.set('shopId', rawObj.searchParams.get('shopId'));
      }
      return affiliateManager.cleanProductUrl(canonObj.toString());
    } catch (_) {
      return affiliateManager.cleanProductUrl(rawTargetUrl);
    }
  }

  // 1. Canlıdaki aktif ana model fırsatı (650 TL)
  const baseModelUrl = 'https://www.hepsiburada.com/defacto-su-itici-kapusonlu-fermuarli-sisme-mont-erkek-cocuk-a1875a825au-pm-HBC00009Z5HVU?magaza=DeFacto';
  const canonicalCleanUrl = affiliateManager.cleanProductUrl(baseModelUrl);

  const databaseWithActiveDeal = [
    {
      id: 'telegram_2242121712_6890',
      cleanUrl: canonicalCleanUrl,
      price: 650,
      isApproved: true,
      createdAt: new Date()
    }
  ];

  // 2. Yeni gelen 11-12 Yaş varyant linki (800 TL)
  const variantRawUrl1 = 'https://www.hepsiburada.com/defacto-su-itici-kapusonlu-fermuarli-sisme-mont-erkek-cocuk-a1875a825au-p-HBCV00009ZM96N?magaza=DeFacto';
  // Sayfadan kazınan canonical URL
  const htmlCanonicalUrl1 = 'https://www.hepsiburada.com/defacto-su-itici-kapusonlu-fermuarli-sisme-mont-erkek-cocuk-a1875a825au-pm-HBC00009Z5HVU';
  
  const derivedCleanUrl1 = buildCanonicalCleanUrl(variantRawUrl1, htmlCanonicalUrl1);
  assert.strictEqual(derivedCleanUrl1, canonicalCleanUrl, 'Varyantın türetilen cleanUrl değeri ana modelle birebir aynı olmalı');

  // Post-scrape dedup kontrolü: 800 TL vs 650 TL
  const docsForVariant1 = databaseWithActiveDeal.filter(d => d.cleanUrl === derivedCleanUrl1);
  const postCheckVariant1 = evaluatePostScrape(docsForVariant1, 800, 'telegram_1145318392_9490');
  assert.strictEqual(postCheckVariant1.canSave, false, 'Fiyat düşmediği için varyant mükerrer olarak engellenmeli');
  assert.strictEqual(postCheckVariant1.reason, 'fake_price_drop');
  console.log('✅ Test 4a Başarılı: 11-12 Yaş varyantı (800 TL), 650 TL aktif ana model ile eşleştirildi ve engellendi!');

  // 3. Yeni gelen 9-10 Yaş varyant linki (800 TL)
  const variantRawUrl2 = 'https://www.hepsiburada.com/defacto-su-itici-kapusonlu-fermuarli-sisme-mont-erkek-cocuk-a1875a825au-p-HBCV00009ZMAII?magaza=DeFacto';
  const derivedCleanUrl2 = buildCanonicalCleanUrl(variantRawUrl2, htmlCanonicalUrl1);
  assert.strictEqual(derivedCleanUrl2, canonicalCleanUrl, 'İkinci varyantın da türetilen cleanUrl değeri ana modelle birebir aynı olmalı');

  const docsForVariant2 = databaseWithActiveDeal.filter(d => d.cleanUrl === derivedCleanUrl2);
  const postCheckVariant2 = evaluatePostScrape(docsForVariant2, 800, 'telegram_1457742945_89191');
  assert.strictEqual(postCheckVariant2.canSave, false, 'İkinci varyant da mükerrer olarak engellenmeli');
  console.log('✅ Test 4b Başarılı: 9-10 Yaş varyantı da başarıyla mükerrer olarak engellendi!');

  // 4. Zero Deal Loss Testi: Eğer varyant 400 TL gibi gerçek bir indirimle gelseydi
  const postCheckVariantCheap = evaluatePostScrape(docsForVariant1, 400, 'variant_cheap');
  assert.strictEqual(postCheckVariantCheap.canSave, true, 'Gerçek indirimli varyant fırsatı kaçırılmamalı!');
  console.log('✅ Test 4c Başarılı: Zero Deal Loss prensibi doğrulandı, gerçek indirimli varyant onaylandı!');

  console.log('\n🎉 TÜM TESTLER BAŞARIYLA GEÇTİ! Çift kademeli mükerrerlik mimarisi kusursuz.');
}

runTests().catch(err => {
  console.error('❌ Test başarısız:', err);
  process.exit(1);
});
