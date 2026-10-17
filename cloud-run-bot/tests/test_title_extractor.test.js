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
    .trim()
    .replace(/\s+/g, ' ');

  if (!title || title.length < 3) return 'Fırsat Ürünü';
  return title.charAt(0).toUpperCase() + title.slice(1);
}

function extractTitleFromTelegramMessage(messageText) {
  if (!messageText || typeof messageText !== 'string') return 'Fırsat Ürünü';
  const lines = messageText.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
  
  const isSkipLine = (line) => {
    const l = line.toLowerCase();
    // 1. Link içeren satırlar
    if (/https?:\/\/|t\.me\/|hb\.biz|ty\.gl|amzn\.to|bit\.ly|amzlinks/i.test(l)) return true;
    // 2. Hashtag ve reklam ibareleri
    if (/#işbirliği|#reklam|^#|^işbirliği$|^reklam$/i.test(l)) return true;
    // 3. Fiyat, taksit ve kupon kodu satırları
    if (/^[✅🔥*•\-–🔺!⚡️\s]*(\d{1,3}(?:\.\d{3})*|\d+)(?:,\d{2})?\s*(?:tl|₺|lira)/i.test(l)) return true;
    if (/^[✅🔥*•\-–🔺!⚡️\s]*₺\s*\d+/i.test(l)) return true;
    if (/^\s*\d+\s*x\s*\d+/i.test(l)) return true;
    if (/kupon kodu|sepette/i.test(l)) return true;
    // 4. Promosyon ve indirim sloganları
    if (/\b(?:son \d+ (?:ay|yıl|hafta|gün)(?:ın)? en düşük|en düşük fiyat|tarihi (?:en düşük|fiyat|dip)|kaçırma(?:yın)?|günün fırsatı|büyük (?:indirim|fırsat)|efsane (?:indirim|fiyat)|şok (?:fiyat|indirim)|süper (?:fiyat|indirim)|dibe vurdu|tükenmeden al|çökün|koşun|kargo bedava|ücretsiz kargo|piyasa fiyatı)/i.test(l)) return true;
    return false;
  };

  for (const line of lines) {
    if (!isSkipLine(line) && /[a-zA-ZçğıöşüÇĞİÖŞÜ]/.test(line) && line.length >= 5) {
      const candidate = cleanFallbackTitle(line);
      if (candidate && candidate !== 'Fırsat Ürünü' && candidate.length >= 5) {
        return candidate;
      }
    }
  }

  return cleanFallbackTitle(lines[0] || messageText);
}

// TESTLER
const sample1 = `🔥 Strong 4K Ultra HD 65" 165 Ekran Uydu Alıcılı Google Smart QLED TV

✅ 23.000 TL

🔺 Son 6 Ayın En Düşük Fiyatı ❗️

🔗https://app.hb.biz/a5gSQQToGazK

#işbirliği #reklam`;

const sample2 = `Xiaomi Redmi Note 13 Pro 256GB 8GB Ram Akıllı Telefon
₺12.499 TL
Günün Fırsatı Kaçırmayın!
https://amzn.to/3xyz`;

console.log('TEST 1 SONUCU:');
console.log(extractTitleFromTelegramMessage(sample1));
console.log('\nTEST 2 SONUCU:');
console.log(extractTitleFromTelegramMessage(sample2));
