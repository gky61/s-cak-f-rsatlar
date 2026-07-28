function createTurkeyDate(year, monthIndex, day, hours, minutes, seconds, ms) {
  // Turkey is UTC+3 (3 * 3600 * 1000 = 10,800,000 ms)
  // Date in UTC corresponding to (year, monthIndex, day, hours, minutes, seconds, ms) in UTC+3:
  const utcMs = Date.UTC(year, monthIndex, day, hours, minutes, seconds, ms) - (3 * 3600 * 1000);
  return new Date(utcMs);
}

function testTurkeyTimezoneDateCreation() {
  // Example: 1 Temmuz 2026 - 31 Temmuz 2026
  const startDate = createTurkeyDate(2026, 6, 1, 0, 0, 0, 0); // 1 Temmuz 00:00:00 UTC+3
  const endDate = createTurkeyDate(2026, 6, 31, 23, 59, 59, 999); // 31 Temmuz 23:59:59.999 UTC+3

  console.log('--- ISO Strings (UTC) saved to Firestore ---');
  console.log('startDate ISO:', startDate.toISOString());
  console.log('endDate ISO:  ', endDate.toISOString());

  console.log('\n--- Formatted in UTC+3 (Turkey Timezone) ---');
  const trOptions = { timeZone: 'Europe/Istanbul', dateStyle: 'full', timeStyle: 'long' };
  console.log('startDate in Turkey:', new Intl.DateTimeFormat('tr-TR', trOptions).format(startDate));
  console.log('endDate in Turkey:  ', new Intl.DateTimeFormat('tr-TR', trOptions).format(endDate));
}

testTurkeyTimezoneDateCreation();
