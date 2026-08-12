const assert = require('assert');
const {
  hasAdvertisingDisclosure,
  ensureAdvertisingDisclosure,
} = require('../advertising_compliance_service');

function runTests() {
  console.log('🧪 Testing Advertising Compliance Service (#tanıtım Dönüşümü)...\n');

  // Test 1: Metinde #reklam varsa -> #tanıtım'a çevrilmeli
  const t1 = 'Harika indirimli spor ayakkabı!\n\n#reklam';
  const r1 = ensureAdvertisingDisclosure(t1);
  assert.strictEqual(r1, 'Harika indirimli spor ayakkabı!\n\n#tanıtım');
  console.log('✅ Test 1: #reklam etiketi başarıyla #tanıtım olarak dönüştürüldü.');

  // Test 2: Metinde #işbirliği varsa -> #tanıtım'a çevrilmeli
  const t2 = 'Philips Kahve Makinesi indirimi #işbirliği';
  const r2 = ensureAdvertisingDisclosure(t2);
  assert.strictEqual(r2, 'Philips Kahve Makinesi indirimi\n\n#tanıtım');
  console.log('✅ Test 2: #işbirliği etiketi #tanıtım olarak dönüştürüldü.');

  // Test 3: Büyük harfli [REKLAM] ibaresi -> #tanıtım'a çevrilmeli
  const t3 = 'Samsung OLED TV Fırsatı [REKLAM]';
  const r3 = ensureAdvertisingDisclosure(t3);
  assert.strictEqual(r3, 'Samsung OLED TV Fırsatı\n\n#tanıtım');
  console.log('✅ Test 3: [REKLAM] ibaresi #tanıtım olarak dönüştürüldü.');

  // Test 4: Zaten #tanıtım içeren metin -> Mükerrer yapmadan tek #tanıtım kalmalı
  const t4 = 'Zara Keten Gömlek İndirimi\n\n#tanıtım';
  const r4 = ensureAdvertisingDisclosure(t4);
  assert.strictEqual(r4, 'Zara Keten Gömlek İndirimi\n\n#tanıtım');
  console.log('✅ Test 4: Zaten #tanıtım olan metin temiz şekilde korundu.');

  // Test 5: Etiketsiz açıklama -> Sonuna \n\n#tanıtım eklenmeli
  const t5 = 'Stanley Termos 1.9L Yeşil renk son 10 stok.';
  const r5 = ensureAdvertisingDisclosure(t5);
  assert.strictEqual(r5, 'Stanley Termos 1.9L Yeşil renk son 10 stok.\n\n#tanıtım');
  console.log('✅ Test 5: Etiketsiz açıklamaya otomatik #tanıtım eklendi.');

  // Test 6: Boş metin -> 'Fırsat Ürünü Detayları\n\n#tanıtım'
  const t6 = '';
  const r6 = ensureAdvertisingDisclosure(t6);
  assert.strictEqual(r6, 'Fırsat Ürünü Detayları\n\n#tanıtım');
  console.log('✅ Test 6: Boş metne varsayılan metin + #tanıtım eklendi.');

  // Test 7: Sadece '#reklam' yazan metin
  const t7 = '#reklam';
  const r7 = ensureAdvertisingDisclosure(t7);
  assert.strictEqual(r7, 'Fırsat Ürünü Detayları\n\n#tanıtım');
  console.log('✅ Test 7: Sadece #reklam yazan metin düzgün ele alındı.');

  console.log('\n🎉 ALL #tanıtım ADVERTISING COMPLIANCE TESTS PASSED SUCCESSFULLY!');
}

runTests();
