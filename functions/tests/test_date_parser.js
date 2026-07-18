const MONTHS_MAP = {
  'ocak': 0, 'subat': 1, 'şubat': 1, 'mart': 2, 'nisan': 3,
  'mayis': 4, 'mayıs': 4, 'haziran': 5, 'temmuz': 6, 'agustos': 7, 'ağustos': 7,
  'eylul': 8, 'eylül': 8, 'ekim': 9, 'kasim': 10, 'kasım': 10, 'aralik': 11, 'aralık': 11
};

function parseDatesFromSpan(spanText, baslangicTarihiFromUrl) {
  if (!spanText) return null;
  const normalized = spanText.toLowerCase().replace(/\s+/g, ' ').trim();
  
  // Split by dash or en-dash
  const parts = normalized.split(/[-–]/);
  if (parts.length === 0) return null;

  const urlYear = baslangicTarihiFromUrl.getFullYear();
  
  function parseSinglePart(partText) {
    // Match day (digits) and month name
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
      // If end month is earlier than start month, it has crossed into the next year
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

function formatDateLocal(d) {
  const yy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yy}-${mm}-${dd}`;
}

// Tests
const testCases = [
  { spanText: "22 Haziran - 31 Aralık", urlDate: new Date(2026, 5, 22), expectedStart: "2026-06-22", expectedEnd: "2026-12-31" },
  { spanText: "24 Mart - 14 Nisan", urlDate: new Date(2026, 2, 24), expectedStart: "2026-03-24", expectedEnd: "2026-04-14" },
  { spanText: "30 Aralık - 5 Ocak", urlDate: new Date(2026, 11, 30), expectedStart: "2026-12-30", expectedEnd: "2027-01-05" },
  { spanText: "15 Temmuz", urlDate: new Date(2026, 6, 15), expectedStart: "2026-07-15", expectedEnd: "2026-07-15" }
];

console.log("🧪 Running Date Parser Tests (Local Time):");
testCases.forEach((tc, idx) => {
  const result = parseDatesFromSpan(tc.spanText, tc.urlDate);
  if (result) {
    const startStr = formatDateLocal(result.startDate);
    const endStr = formatDateLocal(result.endDate);
    const pass = startStr === tc.expectedStart && endStr === tc.expectedEnd;
    console.log(`Case ${idx + 1}: ${pass ? '✅ PASS' : '❌ FAIL'} (Got: ${startStr} to ${endStr}, Expected: ${tc.expectedStart} to ${tc.expectedEnd})`);
  } else {
    console.log(`Case ${idx + 1}: ❌ FAIL (Returned null)`);
  }
});
