const assert = require('assert');
const categoryDetectionService = require('../category_detection_service.js');

function runTests() {
  console.log('🧪 Testing Getir & Migros Supermarket Category Detection (Node.js)...\n');

  // Test 1: Getir URL with grocery item
  const res1 = categoryDetectionService.detectCategory(
    'Chunkies & Magnum Badem & Nogger Paketi',
    [],
    'https://getir.com/urun/chunkies-magnum-badem-nogger-paketi-mkbemgrdz5/'
  );
  console.log('1. Getir URL (Chunkies & Magnum):', res1);
  assert.strictEqual(res1.categoryId, 'supermarket');

  // Test 2: Migros URL with milk
  const res2 = categoryDetectionService.detectCategory(
    'Migros Süt 1 L',
    [],
    'https://www.migros.com.tr/migros-sut-1-l-p-12345'
  );
  console.log('2. Migros URL (Migros Süt):', res2);
  assert.strictEqual(res2.categoryId, 'supermarket');

  // Test 3: Getir URL with deterjan (subCategory test)
  const res3 = categoryDetectionService.detectCategory(
    'Ariel Sıvı Çamaşır Deterjanı 1.5 L',
    [],
    'https://getir.com/urun/ariel-sivi-deterjan'
  );
  console.log('3. Getir URL (Ariel Deterjan):', res3);
  assert.strictEqual(res3.categoryId, 'supermarket');
  assert.strictEqual(res3.subCategory, 'Deterjan & Temizlik');

  // Test 4: Migros store name parameter
  const res4 = categoryDetectionService.detectCategory(
    'Bilinmeyen Ürün Adı Paket 123',
    [],
    'https://example.com/item',
    'Migros'
  );
  console.log('4. Migros Store Param:', res4);
  assert.strictEqual(res4.categoryId, 'supermarket');
  assert.strictEqual(res4.subCategory, 'Gıda Ürünleri');

  // Test 5: Getir store name parameter
  const res5 = categoryDetectionService.detectCategory(
    'Özel Fırsat Paketi',
    [],
    'https://example.com/item',
    'Getir'
  );
  console.log('5. Getir Store Param:', res5);
  assert.strictEqual(res5.categoryId, 'supermarket');

  console.log('\n✅ ALL GETIR & MIGROS CATEGORY TESTS PASSED!');
}

runTests();
