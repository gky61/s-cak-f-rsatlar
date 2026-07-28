const cheerio = require('cheerio');

const MONTHS_MAP = {
  'ocak': 0, 'subat': 1, 'şubat': 1, 'mart': 2, 'nisan': 3,
  'mayis': 4, 'mayıs': 4, 'haziran': 5, 'temmuz': 6, 'agustos': 7, 'ağustos': 7,
  'eylul': 8, 'eylül': 8, 'ekim': 9, 'kasim': 10, 'kasım': 10, 'aralik': 11, 'aralık': 11
};

/**
 * Clean and parse start and end dates strictly from span#br_s or DOM text.
 * Example spanTexts:
 * - "1 Temmuz - 31 Temmuz"
 * - "29 Temmuz - 11 Ağustos"
 * - "28 Aralık - 4 Ocak"
 * - "24 Temmuz"
 */
function parseDatesFromSpan(spanText, urlYear = new Date().getFullYear()) {
  if (!spanText) return null;
  const normalized = spanText.toLowerCase().replace(/\s+/g, ' ').trim();
  
  // Split by dash, en-dash, or em-dash
  const parts = normalized.split(/\s*[-–—]\s*/);
  if (parts.length === 0) return null;

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
      const startDate = new Date(urlYear, startPart.month, startPart.day, 0, 0, 0, 0);
      let endYear = urlYear;
      if (endPart.month < startPart.month) {
        endYear = urlYear + 1;
      }
      const endDate = new Date(endYear, endPart.month, endPart.day, 23, 59, 59, 999);
      return { startDate, endDate };
    }
  } else if (parts.length === 1) {
    const singlePart = parseSinglePart(parts[0]);
    if (singlePart) {
      const startDate = new Date(urlYear, singlePart.month, singlePart.day, 0, 0, 0, 0);
      const endDate = new Date(urlYear, singlePart.month, singlePart.day, 23, 59, 59, 999);
      return { startDate, endDate };
    }
  }
  
  return null;
}

function parseYearFromUrl(url) {
  const match = url.match(/(\d{4})/);
  if (match) {
    const year = parseInt(match[1], 10);
    if (year >= 2024 && year <= 2030) {
      return year;
    }
  }
  return new Date().getFullYear();
}

function testSpanParser() {
  const samples = [
    { text: "1 Temmuz - 31 Temmuz", url: "/brosurler/macrocenter-1-temmuz-2026-aktuel-katalogu-58910" },
    { text: "29 Temmuz - 11 Ağustos", url: "/brosurler/bizimtoptan-29-temmuz-2026-aktuel-katalogu-59879" },
    { text: "28 Aralık - 5 Ocak", url: "/brosurler/bim-28-aralik-2026-aktuel-katalogu-59000" },
    { text: "24 Temmuz", url: "/brosurler/a101-24-temmuz-2026-aktuel-katalogu-59001" },
    { text: " 15  Temmuz  -  28  Temmuz ", url: "/brosurler/bizimtoptan-15-temmuz-2026-aktuel-59407" }
  ];

  for (const s of samples) {
    const year = parseYearFromUrl(s.url);
    const result = parseDatesFromSpan(s.text, year);
    console.log(`Input: "${s.text}" (Year: ${year})`);
    if (result) {
      console.log(`  -> Start: ${result.startDate.toLocaleDateString('tr-TR')} ${result.startDate.toLocaleTimeString('tr-TR')}`);
      console.log(`  -> End:   ${result.endDate.toLocaleDateString('tr-TR')} ${result.endDate.toLocaleTimeString('tr-TR')}`);
    } else {
      console.log(`  -> FAILED PARSE`);
    }
    console.log('---');
  }
}

testSpanParser();
