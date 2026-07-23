const assert = require('assert');
const categoryDetectionService = require('../category_detection_service.js');

// Copy cleanFallbackTitle logic from telegram_bot.js to test
function cleanFallbackTitle(rawTitle) {
  if (!rawTitle) return 'Fırsat Ürünü';

  let title = rawTitle.trim();

  const invalidTitles = ['google search', 'google', 'just a moment...', 'attention required!', 'access denied', 'robot check', 'security check', 'cloudflare', '404 not found', 'error 404', 'fırsat ürünü'];
  if (invalidTitles.includes(title.toLowerCase())) {
    return 'Fırsat Ürünü';
  }

  title = title.replace(/[\u{1F300}-\u{1F9FF}]|[\u{2700}-\u{27BF}]|[\u{2600}-\u{26FF}]/gu, '');
  title = title.replace(/[^\x00-\x7F\u00C0-\u017F]/g, '');
  title = title.replace(/\//g, ' ');

  title = title.replace(/(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)\s*(?:TL|₺|Lira)/gi, '');
  title = title.replace(/\b\d+\s*(?:TL|₺)/gi, '');
  title = title.replace(/\b\d+\s*lira/gi, '');
  title = title.replace(/₺\s*\d+(?:\.\d{3})*(?:,\d{2})?/g, '');
  title = title.replace(/%\d+\s*(?:indirim)?/gi, '');

  title = title.replace(/:\s*Amazon\.com\.tr.*$/gi, '');
  title = title.replace(/:\s*Hepsiburada.*$/gi, '');
  title = title.replace(/:\s*Trendyol.*$/gi, '');
  title = title.replace(/:\s*N11.*$/gi, '');
  title = title.replace(/:\s*Pazarama.*$/gi, '');

  if (title.includes(':')) {
    const parts = title.split(':');
    const firstPart = parts[0].trim();
    const secondPart = parts[1] ? parts[1].trim() : '';

    if (firstPart.length >= 3 && !firstPart.toLowerCase().includes('fırsat') && !firstPart.toLowerCase().includes('indirim')) {
      title = firstPart;
    } else if (secondPart.length > 5) {
      title = secondPart;
    } else {
      title = firstPart;
    }
  }

  const promoWords = [
    /hepsiburada(?:'da|da)?/gi,
    /trendyol(?:'da|da)?/gi,
    /amazon(?:'da|da)?/gi,
    /n11(?:'de|de)?/gi,
    /a101(?:'de|de)?/gi,
    /bim(?:'de|de)?/gi,
    /şok(?:'ta|ta)?/gi,
    /migros(?:'ta|ta)?/gi,
    /günün fırsatı/gi,
    /fırsat/gi,
    /indirim(?:li)?/gi,
    /kaçırma(?:yın)?/gi,
    /büyük indirim/gi,
    /süper fiyat/gi,
    /şok fiyat/gi,
    /çok iyi fiyat/gi,
    /kaçırılmayacak/gi,
    /koşun/gi,
    /sepette/gi,
    /ücretsiz kargo/gi,
    /kargo bedava/gi,
    /dev indirim/gi,
    /efsane indirim/gi,
    /kampanya/gi,
    /sadece/gi,
    /bugüne özel/gi,
    /yerine/gi,
    /fiyatıyla/gi,
    /fiyat/gi
  ];

  for (const regex of promoWords) {
    title = title.replace(regex, '');
  }

  title = title.trim()
    .replace(/^[-:,\s!📣🚨🔥.*_]+/g, '')
    .replace(/[-:,\s!📣🚨🔥.*_]+$/g, '')
    .trim();

  title = title.replace(/\s+/g, ' ');

  if (title.length > 0) {
    title = title.charAt(0).toUpperCase() + title.slice(1);
  }

  if (title.length > 80) {
    title = title.substring(0, 80).trim() + '...';
  }

  const lowerTitle = title.toLowerCase();
  if (lowerTitle === 'com.tr' || lowerTitle === 'com' || lowerTitle === 'net' || lowerTitle === 'org' || invalidTitles.includes(lowerTitle)) {
    return 'Fırsat Ürünü';
  }

  return title || 'Fırsat Ürünü';
}

async function run() {
  console.log('Testing cleanFallbackTitle:');
  const t1 = cleanFallbackTitle("Dove Şampuan Avocado Dökülme Karşıtı 375 ml : Amazon.com.tr: Kişisel Bakım ve Kozmetik");
  console.log('Test 1 (Dove Amazon):', t1);
  assert.strictEqual(t1, "Dove Şampuan Avocado Dökülme Karşıtı 375 ml");

  const t2 = cleanFallbackTitle("Google Search");
  console.log('Test 2 (Google Search):', t2);
  assert.strictEqual(t2, "Fırsat Ürünü");

  console.log('\nTesting Category Detection for Dove:');
  const catResult = categoryDetectionService.detectCategory(
    "Dove Şampuan Avocado Dökülme Karşıtı 375 ml",
    [],
    "Dove Şampuan Avocado Dökülme Karşıtı 375 ml 118.02 TL"
  );
  console.log('Category result:', catResult);
  assert.strictEqual(catResult.categoryId, "kozmetik");

  console.log('\n✅ ALL TITLE & CATEGORY FIX TESTS PASSED!');
}

run();
