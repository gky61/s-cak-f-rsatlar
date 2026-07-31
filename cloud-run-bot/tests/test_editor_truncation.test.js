const assert = require('assert');

function truncateEditorAndFooterInfo(rawText) {
  if (!rawText) return '';

  const lines = rawText.split(/\r?\n/);
  const cleanLines = [];

  const forbiddenKeywords = [
    'editör',
    'editor',
    'yazar',
    'paylaşan',
    'paylasan',
    'hazırlayan',
    'hazirlayan',
    'ekleyen',
    'yayınlayan',
    'yayinlayan',
    'gönderen',
    'gonderen',
    'moderatör',
    'moderator',
    'admin',
    'kaynak:',
    'kanalımız',
    'kanalimiz',
    'grubumuz',
    'takip edin',
    'takipedin',
    'katılın',
    'katilin',
    'sponsorlu',
    'işbirliği',
    'isbirligi',
    'reklam içerir',
    'reklam icerir'
  ];

  for (const line of lines) {
    const trimmedLine = line.trim();
    if (!trimmedLine) {
      cleanLines.push(line);
      continue;
    }

    const lowerStandard = trimmedLine.toLowerCase();
    const lowerTurkish = trimmedLine.toLocaleLowerCase('tr-TR');

    const hasForbiddenWord = forbiddenKeywords.some(keyword => 
      lowerStandard.includes(keyword) || lowerTurkish.includes(keyword)
    );

    if (hasForbiddenWord) {
      break;
    }

    cleanLines.push(line);
  }

  return cleanLines.join('\n').trim();
}

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

  // Test 2: "YAZAR : Mehmet" (Uppercase)
  const t2 = `Anker Bluetooth Kulaklık
%30 İndirimde

YAZAR : Mehmet
Kanalımıza katılın`;
  const r2 = truncateEditorAndFooterInfo(t2);
  console.log('2. Test YAZAR:\n', r2);
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

  console.log('\n✅ ALL DESCRIPTION TRUNCATION TESTS PASSED!');
}

runTests();
