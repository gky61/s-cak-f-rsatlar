const cheerio = require('cheerio');

const MONTHS_MAP = {
  'ocak': 0, 'subat': 1, 'şubat': 1, 'mart': 2, 'nisan': 3,
  'mayis': 4, 'mayıs': 4, 'haziran': 5, 'temmuz': 6, 'agustos': 7, 'ağustos': 7,
  'eylul': 8, 'eylül': 8, 'ekim': 9, 'kasim': 10, 'kasım': 10, 'aralik': 11, 'aralık': 11
};

const WEEKDAYS_MAP = {
  'pazartesi': 1, 'sali': 2, 'salı': 2, 'carsamba': 3, 'çarşamba': 3,
  'persembe': 4, 'perşembe': 4, 'cuma': 5, 'cumartesi': 6, 'pazar': 0
};

function parseDatesFromSpan(spanText, baslangicTarihiFromUrl) {
  if (!spanText) return null;
  const normalized = spanText.toLowerCase().replace(/\s+/g, ' ').trim();
  
  const parts = normalized.split(/[-–]/);
  if (parts.length === 0) return null;

  const urlYear = baslangicTarihiFromUrl.getFullYear();
  
  function parseSinglePart(partText) {
    const match = partText.trim().match(/(\d+)\s+([a-zA-ZğüşöçıİĞÜŞÖÇI]+)/);
    if (match) {
      const day = parseInt(match[1], 10);
      const monthStr = match[2];
      const month = MONTHS_MAP[monthStr];
      if (month !== undefined) {
        return { day, month };
      }
    }
    return null;
  }

  if (parts.length === 2) {
    const startPart = parseSinglePart(parts[0]);
    const endPart = parseSinglePart(parts[1]);

    if (startPart && endPart) {
      const startDate = new Date(urlYear, startPart.month, startPart.day);
      startDate.setHours(0, 0, 0, 0);
      let endYear = urlYear;
      if (endPart.month < startPart.month) {
        endYear = urlYear + 1;
      }
      const endDate = new Date(endYear, endPart.month, endPart.day);
      endDate.setHours(23, 59, 59, 999);
      return { startDate, endDate };
    }
  } else if (parts.length === 1) {
    const singlePart = parseSinglePart(parts[0]);
    if (singlePart) {
      const startDate = new Date(urlYear, singlePart.month, singlePart.day);
      startDate.setHours(0, 0, 0, 0);
      const endDate = new Date(urlYear, singlePart.month, singlePart.day);
      endDate.setHours(23, 59, 59, 999);
      return { startDate, endDate };
    }
  }
  
  return null;
}

function parseDateFromUrl(url) {
  const match = url.match(/(\d+)-([a-zA-ZğüşöçıİĞÜŞÖÇI]+)-(\d{4})/);
  if (match) {
    const day = parseInt(match[1], 10);
    const monthStr = match[2].toLowerCase();
    const year = parseInt(match[3], 10);
    const month = MONTHS_MAP[monthStr] !== undefined ? MONTHS_MAP[monthStr] : 0;
    return new Date(year, month, day);
  }
  return new Date();
}

function calculateEndDate(baslangicTarihi, timeRemainingText) {
  const normalizedText = timeRemainingText.toLowerCase().trim();
  const today = new Date();
  
  const gunMatch = normalizedText.match(/(\d+)\s+gün\s+kaldı/);
  if (gunMatch) {
    const days = parseInt(gunMatch[1], 10);
    const endDate = new Date(today.getTime() + days * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  const haftaMatch = normalizedText.match(/(\d+)\s+hafta\s+kaldı/);
  if (haftaMatch) {
    const weeks = parseInt(haftaMatch[1], 10);
    const endDate = new Date(today.getTime() + weeks * 7 * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  const ayMatch = normalizedText.match(/(\d+)\s+ay\s+kaldı/);
  if (ayMatch) {
    const months = parseInt(ayMatch[1], 10);
    const endDate = new Date(today.getTime() + months * 30 * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  if (normalizedText.includes('başlıyor')) {
    const endDate = new Date(baslangicTarihi.getTime() + 7 * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  if (normalizedText.includes('bugün son')) {
    const endDate = new Date(today);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  if (normalizedText.includes('yarın son')) {
    const endDate = new Date(today.getTime() + 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  const sonGunMatch = normalizedText.match(/son\s+gün\s+([a-zA-ZğüşöçıİĞÜŞÖÇI]+)/);
  if (sonGunMatch) {
    const dayName = sonGunMatch[1].toLowerCase();
    if (WEEKDAYS_MAP[dayName] !== undefined) {
      const targetDay = WEEKDAYS_MAP[dayName];
      const currentDay = today.getDay();
      let daysToAdd = (targetDay - currentDay + 7) % 7;
      if (daysToAdd === 0) daysToAdd = 7;
      const endDate = new Date(today.getTime() + daysToAdd * 24 * 60 * 60 * 1000);
      endDate.setHours(23, 59, 59, 999);
      return endDate;
    }
  }

  const endDate = new Date(baslangicTarihi.getTime() + 7 * 24 * 60 * 60 * 1000);
  endDate.setHours(23, 59, 59, 999);
  return endDate;
}

async function testMacrocenterDate() {
  const url = 'https://www.akakce.com/brosurler/macrocenter-1-temmuz-2026-aktuel-katalogu-macrostyle-brosuru-58910';
  const listUrl = 'https://www.akakce.com/brosurler/macrocenter';

  console.log('--- Testing List Page Parse ---');
  const proxyHostList = 'www-akakce-com.translate.goog';
  const proxyListUrl = `https://${proxyHostList}/brosurler/macrocenter?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;
  
  const listRes = await fetch(proxyListUrl, {
    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }
  });
  const listHtml = await listRes.text();
  const $list = cheerio.load(listHtml);
  
  let timeRemainingText = '';
  $list('ul#BLI li').each((i, el) => {
    const href = $list(el).find('a').attr('href') || '';
    if (href.includes('58910')) {
      timeRemainingText = $list(el).find('span.b').text().trim();
    }
  });

  console.log(`URL: ${url}`);
  console.log(`timeRemainingText from List Page: "${timeRemainingText}"`);

  console.log('\n--- Testing Detail Page Parse ---');
  const proxyDetailUrl = `https://${proxyHostList}/brosurler/macrocenter-1-temmuz-2026-aktuel-katalogu-macrostyle-brosuru-58910?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;
  const detailRes = await fetch(proxyDetailUrl, {
    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }
  });
  const detailHtml = await detailRes.text();
  const $detail = cheerio.load(detailHtml);

  const spanBrS = $detail('#br_s').text().trim();
  console.log(`span#br_s text: "${spanBrS}"`);

  // Log other potential date selectors
  console.log(`h1 text: "${$detail('h1').text().trim()}"`);
  console.log(`.blid text: "${$detail('.blid').text().trim()}"`);
  console.log(`all spans text:`, $detail('span').map((i, el) => $detail(el).text().trim()).get());

  const baslangicFromUrl = parseDateFromUrl(url);
  const bitisCalculated = calculateEndDate(baslangicFromUrl, timeRemainingText);
  const dateSpanParsed = parseDatesFromSpan(spanBrS, baslangicFromUrl);

  console.log('\n--- Result Date Calculations ---');
  console.log(`1. Başlangıç (URL'den): ${baslangicFromUrl.toISOString()} (${baslangicFromUrl.toLocaleDateString('tr-TR')})`);
  console.log(`2. Bitiş (Hesaplanan): ${bitisCalculated.toISOString()} (${bitisCalculated.toLocaleDateString('tr-TR')})`);
  if (dateSpanParsed) {
    console.log(`3. Overridden Start: ${dateSpanParsed.startDate.toISOString()} (${dateSpanParsed.startDate.toLocaleDateString('tr-TR')})`);
    console.log(`4. Overridden End: ${dateSpanParsed.endDate.toISOString()} (${dateSpanParsed.endDate.toLocaleDateString('tr-TR')})`);
  } else {
    console.log(`3. span#br_s Parse Sonucu: NULL (Override edilemedi)`);
  }
}

testMacrocenterDate();
