const fs = require('fs');

const logs = JSON.parse(fs.readFileSync('documentation/aktuel-logs/aktuelLogs.json', 'utf8'));

console.log(`Total log entries: ${logs.length}`);

const skippedLogs = logs.filter(l => {
  const text = (l.textPayload || JSON.stringify(l)).toLowerCase();
  return text.includes('skipping') || text.includes('no pages found') || text.includes('failed to fetch') || l.severity === 'WARNING';
});

console.log(`Found ${skippedLogs.length} warning/skipped logs:\n`);

skippedLogs.forEach(l => {
  console.log(`[${l.timestamp}] [${l.severity}] ${l.textPayload}`);
});
