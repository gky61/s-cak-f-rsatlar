const assert = require('assert');
const {
  formatAndEnrichDescription,
  truncateEditorAndFooterInfo,
  isTruncationTriggerLine
} = require('../description_formatter_service');

function runTests() {
  console.log('🧪 Testing FırsatKolik Description Formatter & Brand Enrichment Engine...\n');

  // Test 1: EXACT SCREENSHOT TEST (The problem reported by user)
  console.log('--- TEST 1: User Screenshot Replica ---');
  const userScreenshotText = `Familia Plus 3 Katlı Tuvalet Kağıdı Sihirli Çiçekler 32'li 🔎

💳 207 TL
⚠️ 3 adet ekleyin, indirim ödeme aşamasında uygulanır

🛍️ Amazon (Satıcı : Amazon) Tanıtım

👉 FIRSATA GİT 👈

📣 Diğer kanallarımız için TAZEFIRSAT.com

#tanıtım`;

  const dealTitle = "Familia Plus 3 Katlı Tuvalet Kağıdı Sihirli Çiçekler 32'li";
  const result1 = formatAndEnrichDescription({
    rawText: userScreenshotText,
    links: ['https://amzn.to/3Bxxxxx'],
    title: dealTitle,
    store: 'Amazon',
    category: 'temizlik',
    seed: 'deal_12345'
  });

  console.log('Output for Test 1:\n' + result1 + '\n');

  // Assertions for Test 1:
  // Must NOT contain competitor channel or website
  assert.strictEqual(result1.includes('TAZEFIRSAT'), false, 'Competitor TAZEFIRSAT must be stripped');
  assert.strictEqual(result1.includes('kanallarımız'), false, 'kanallarımız must be stripped');
  assert.strictEqual(result1.includes('Diğer kanallarımız'), false, 'Diğer kanallarımız must be stripped');

  // Must NOT contain CTA "FIRSATA GİT"
  assert.strictEqual(result1.includes('FIRSATA GİT'), false, 'CTA FIRSATA GİT must be stripped');

  // Must NOT repeat product title in body
  assert.strictEqual(result1.includes('Familia Plus 3 Katlı Tuvalet Kağıdı Sihirli Çiçekler 32\'li 🔎'), false, 'Duplicate title must be stripped');

  // Must NOT contain bare price line
  assert.strictEqual(result1.includes('💳 207 TL'), false, 'Bare price line must be stripped');

  // MUST contain the valuable campaign condition!
  assert.strictEqual(result1.includes('3 adet ekleyin, indirim ödeme aşamasında uygulanır'), true, 'Campaign condition MUST be preserved!');

  // MUST contain FırsatKolik branding header and footer
  assert.strictEqual(result1.includes('FırsatKolik'), true, 'Must contain FırsatKolik branding');
  assert.strictEqual(result1.includes('#tanıtım'), true, 'Must end with #tanıtım');

  console.log('✅ Test 1 Passed: User screenshot problem completely solved!\n');

  // Test 2: Kuponlu ve Telegram Linkli Paylaşım
  console.log('--- TEST 2: Deal with Coupon and Channel link ---');
  const couponText = `Philips Hue Akıllı Başlangıç Seti
Fiyat: 1.499 TL
Kupon Kodu: HUE200 ile sepette 200 TL anında indirim!
Satıcı: Teknosa
Satın Almak İçin: https://teknosa.com/philips-hue
Telegram kanalımıza abone olun: t.me/indirimler`;

  const result2 = formatAndEnrichDescription({
    rawText: couponText,
    links: ['https://teknosa.com/philips-hue'],
    title: 'Philips Hue Akıllı Başlangıç Seti',
    store: 'Teknosa',
    category: 'elektronik',
    seed: 'deal_hue'
  });

  console.log('Output for Test 2:\n' + result2 + '\n');
  assert.strictEqual(result2.includes('HUE200'), true, 'Coupon code must be preserved');
  assert.strictEqual(result2.includes('t.me'), false, 'Telegram link must be stripped');
  assert.strictEqual(result2.includes('Satın Almak İçin'), false, 'CTA must be stripped');
  assert.strictEqual(result2.includes('#tanıtım'), true, 'Must include #tanıtım');

  console.log('✅ Test 2 Passed: Coupon preserved, channel truncated!\n');

  // Test 3: Boş Açıklama (Sadece Link Gönderilmiş Durum)
  console.log('--- TEST 3: Empty description fallback ---');
  const result3 = formatAndEnrichDescription({
    rawText: '',
    links: ['https://amazon.com.tr/dp/B0000000'],
    title: 'Apple AirPods Pro 2',
    store: 'Amazon',
    category: 'elektronik',
    seed: 'deal_empty'
  });

  console.log('Output for Test 3:\n' + result3 + '\n');
  assert.strictEqual(result3.includes('FırsatKolik'), true, 'Must produce FırsatKolik brand fallback');
  assert.strictEqual(result3.includes('Amazon'), true, 'Must mention store in fallback');
  assert.strictEqual(result3.includes('#tanıtım'), true, 'Must include #tanıtım');

  console.log('✅ Test 3 Passed: Fallback generated smoothly!\n');

  // Test 4: truncateEditorAndFooterInfo backwards compatibility
  console.log('--- TEST 4: Legacy Truncation Compatibility ---');
  const legacyT1 = `Harika fırsat ürünü 100 TL
Kaçırmayın çok ucuz

Editör: Ahmet Yılmaz
Detaylar için kanala katılın`;
  const legR1 = truncateEditorAndFooterInfo(legacyT1);
  assert.strictEqual(legR1, 'Harika fırsat ürünü 100 TL\nKaçırmayın çok ucuz');

  console.log('✅ Test 4 Passed: Legacy tests maintain 100% compatibility!\n');

  // Test 5: "3 al 2 öde" Edge Case (Must NOT be truncated)
  console.log('--- TEST 5: "3 al 2 öde" Kampanya Şartı Korunumu ---');
  assert.strictEqual(isTruncationTriggerLine('3 al 2 öde fırsatı'), false, '"3 al 2 öde" must NOT trigger truncation');
  assert.strictEqual(isTruncationTriggerLine('2 adet alana 1 bedava'), false, '"2 adet alana 1 bedava" must NOT trigger truncation');
  assert.strictEqual(isTruncationTriggerLine('Sepette ek indirim hemen uygulanır'), false, '"Sepette ek indirim" must NOT trigger truncation');
  console.log('✅ Test 5 Passed: Promo conditions with "al" are protected!\n');

  // Test 6: "Çift Kanal RAM" Edge Case (Tech products must NOT be truncated)
  console.log('--- TEST 6: "Çift Kanal RAM" Donanım Terimi Korunumu ---');
  assert.strictEqual(isTruncationTriggerLine('Kingston Fury 16GB Çift Kanal DDR4 RAM'), false, 'RAM dual channel must NOT trigger truncation');
  assert.strictEqual(isTruncationTriggerLine('4 kanallı amfi sistemi'), false, '4 kanallı must NOT trigger truncation');
  assert.strictEqual(isTruncationTriggerLine('Diğer kanallarımız için tıklayın'), true, 'Diğer kanallarımız MUST trigger truncation');
  console.log('✅ Test 6 Passed: Hardware terms with "kanal" are completely safe!\n');

  // Test 7: Doğal Kampanya & Barkod Metni Korunumu (Yapay etiket/emoji eklenmez)
  console.log('--- TEST 7: Doğal Metin Korunumu (Barkod & Kupon) ---');
  const result7 = formatAndEnrichDescription({
    rawText: `Samsung Galaxy S24
Barkod: 880609123456
Kupon Kodu: GALAXY500 ile 500 TL indirim`,
    title: 'Samsung Galaxy S24',
    seed: 'deal_s24'
  });
  console.log('Output for Test 7:\n' + result7 + '\n');
  assert.strictEqual(result7.includes('Kupon Kodu: GALAXY500 ile 500 TL indirim'), true, 'Coupon must be preserved naturally');
  assert.strictEqual(result7.includes('Barkod: 880609123456'), true, 'Barcode must be preserved naturally');
  console.log('✅ Test 7 Passed: Natural descriptions preserved without artificial mutations!\n');

  // Test 8: Kitap Yazarı ve Yayınevi Detayları (ASLA budanmamalı!)
  console.log('--- TEST 8: Kitap Açıklaması ve Yazar Korunumu ---');
  const bookText = `Suç ve Ceza - Hasan Ali Yücel Klasikleri
Fiyat: 120 TL
Yazar: Fyodor Dostoyevski
Çevirmen: Mazlum Beyhan
Yayınevi: Türkiye İş Bankası Kültür Yayınları
Sayfa Sayısı: 687`;

  const result8 = formatAndEnrichDescription({
    rawText: bookText,
    title: 'Suç ve Ceza',
    store: 'Amazon',
    category: 'kitap',
    seed: 'deal_book'
  });
  console.log('Output for Test 8:\n' + result8 + '\n');
  assert.strictEqual(result8.includes('Yazar: Fyodor Dostoyevski'), true, 'Book author must NOT be truncated');
  assert.strictEqual(result8.includes('Sayfa Sayısı: 687'), true, 'Book specs must NOT be truncated');
  console.log('✅ Test 8 Passed: Book author and specifications completely protected!\n');

  // Test 9: Cümle İçi "Tanıtım" ve "Reklam" Kelimelerinin Korunumu
  console.log('--- TEST 9: Cümle İçi Normal Kelimelerin Korunumu ---');
  const inlineWordsText = `Logitech MX Master 3S Kablosuz Mouse
Bu ürün lansmana özel tanıtım fiyatıdır.
Reklam ajansları ve profesyonel tasarımcılar için optimize edilmiştir.
(Tanıtım)`;

  const result9 = formatAndEnrichDescription({
    rawText: inlineWordsText,
    title: 'Logitech MX Master 3S',
    store: 'Hepsiburada',
    category: 'elektronik',
    seed: 'deal_mouse'
  });
  console.log('Output for Test 9:\n' + result9 + '\n');
  assert.strictEqual(result9.includes('lansmana özel tanıtım fiyatıdır'), true, 'Inline "tanıtım" in sentence must NOT be stripped');
  assert.strictEqual(result9.includes('Reklam ajansları ve profesyonel'), true, 'Inline "reklam" in sentence must NOT be stripped');
  assert.strictEqual(result9.includes('(Tanıtım)'), false, 'Standalone tag (Tanıtım) must be cleanly stripped');
  console.log('✅ Test 9 Passed: Sentences preserved intact while removing bracket tags!\n');

  console.log('🎉 ALL 9 ADVANCED TESTS PASSED SUCCESSFULLY! 🚀');
}

runTests();
