const assert = require('assert');

const { truncateEditorAndFooterInfo } = require('../description_formatter_service');

function runTests() {
  console.log('🧪 Testing Telegram Description Editor Truncation...\n');

  // Test 1: "Editör: Ahmet"
  const t1 = `Harika fırsat ürünü 100 TL
Kaçırmayın çok ucuz

Editör: Ahmet Yılmaz
Detaylar için kanala katılın`;
  const r1 = truncateEditorAndFooterInfo(t1);
  console.log('1. Test Editör:\n', r1);
  assert.strictEqual(r1, `Harika fırsat ürünü 100 TL\nKaçırmayın çok ucuz`);

  // Test 2: "Moderatör: Mehmet"
  const t2 = `Anker Bluetooth Kulaklık
%30 İndirimde

Moderatör: Mehmet
Kanalımıza katılın`;
  const r2 = truncateEditorAndFooterInfo(t2);
  console.log('2. Test Moderatör:\n', r2);
  assert.strictEqual(r2, `Anker Bluetooth Kulaklık\n%30 İndirimde`);

  // Test 3: "Paylaşan: @bot"
  const t3 = `Xiaomi Smart Band 8
Fiyat: 899 TL

Paylaşan: @firsat_botu`;
  const r3 = truncateEditorAndFooterInfo(t3);
  console.log('3. Test Paylaşan:\n', r3);
  assert.strictEqual(r3, `Xiaomi Smart Band 8\nFiyat: 899 TL`);

  // Test 4: Normal text without editor info
  const t4 = `Ergonomik Ofis Koltuğu
10 yıl garanti
Sadece bugün özel fiyat!`;
  const r4 = truncateEditorAndFooterInfo(t4);
  console.log('4. Test Normal Text:\n', r4);
  assert.strictEqual(r4, t4);

  // Test 5: Kitap Açıklaması ve Yazar Bilgisi (ASLA KESİLMEMELİ!)
  const t5 = `Sefiller - 2 Cilt Takım
Yazar: Victor Hugo
Çevirmen: Hasan Ali Yücel
Yayınevi: Türkiye İş Bankası Kültür Yayınları`;
  const r5 = truncateEditorAndFooterInfo(t5);
  console.log('5. Test Kitap Yazarı Korunumu:\n', r5);
  assert.strictEqual(r5, t5, 'Book author and publisher info must NEVER be truncated!');

  console.log('\n✅ ALL DESCRIPTION TRUNCATION TESTS PASSED!');
}

runTests();
