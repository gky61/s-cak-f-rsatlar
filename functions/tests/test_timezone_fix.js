// Simulate UTC environment like Google Cloud Functions
process.env.TZ = 'UTC';

const MONTHS_MAP = {
  'ocak': 0, 'subat': 1, 'şubat': 1, 'mart': 2, 'nisan': 3,
  'mayis': 4, 'mayıs': 4, 'haziran': 5, 'temmuz': 6, 'agustos': 7, 'ağustos': 7,
  'eylul': 8, 'eylül': 8, 'ekim': 9, 'kasim': 10, 'kasım': 10, 'aralik': 11, 'aralık': 11
};

// 1. OLD WAY (creating Date in UTC environment without Turkey offset)
function parseDatesOld(spanText, year = 2026) {
  // "1 Temmuz - 31 Temmuz"
  // start: 1 July, end: 31 July
  const startDate = new Date(year, 6, 1, 0, 0, 0, 0); // 2026-07-01T00:00:00.000Z
  const endDate = new Date(year, 6, 31, 23, 59, 59, 999); // 2026-07-31T23:59:59.999Z
  return { startDate, endDate };
}

// 2. CORRECT WAY (Creating dates in Turkey UTC+3 time)
// In Turkey (UTC+3), 1 July 00:00:00 TR = 30 June 21:00:00 UTC (Date.UTC(2026, 5, 30, 21, 0, 0))
// 31 July 23:59:59 TR = 31 July 20:59:59 UTC (Date.UTC(2026, 6, 31, 20, 59, 59))
function createTurkeyDate(year, monthIndex, day, hours, minutes, seconds, ms) {
  // Turkey is UTC+3 (3 hours ahead of UTC).
  // So UTC hour = Turkey hour - 3
  return new Date(Date.UTC(year, monthIndex, day, hours - 3, minutes, seconds, ms));
}

function parseDatesCorrect(spanText, year = 2026) {
  // For 1 Temmuz 00:00:00 Turkey time:
  const startDate = createTurkeyDate(year, 6, 1, 0, 0, 0, 0);
  // For 31 Temmuz 23:59:59 Turkey time:
  const endDate = createTurkeyDate(year, 6, 31, 23, 59, 59, 999);
  return { startDate, endDate };
}

console.log('=== 1. OLD WAY (Creates UTC Date on Cloud Functions) ===');
const old = parseDatesOld("1 Temmuz - 31 Temmuz");
console.log('UTC ISO:', old.startDate.toISOString(), 'to', old.endDate.toISOString());
console.log('TR Timezone format:', old.startDate.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' }), 'to', old.endDate.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' }));

console.log('\n=== 2. CORRECT WAY (Creates exact Turkey local time) ===');
const correct = parseDatesCorrect("1 Temmuz - 31 Temmuz");
console.log('UTC ISO:', correct.startDate.toISOString(), 'to', correct.endDate.toISOString());
console.log('TR Timezone format:', correct.startDate.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' }), 'to', correct.endDate.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' }));
