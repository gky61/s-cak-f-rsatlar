const fs = require('fs');
const path = require('path');

async function runAll() {
  console.log('🏁 NODE.JS SCRAPER PARITY TEST SUITE RUNNER\n');
  const testsDir = path.join(__dirname, 'tests');
  if (!fs.existsSync(testsDir)) {
    console.error('❌ Tests directory not found!');
    process.exit(1);
  }

  const files = fs.readdirSync(testsDir).filter(f => f.endsWith('.test.js'));
  let passedCount = 0;
  let failedCount = 0;

  const originalLog = console.log;
  const originalWarn = console.warn;
  const originalError = console.error;

  for (const file of files) {
    const filePath = path.join(testsDir, file);
    const logs = [];
    
    // Capture console output during test
    console.log = (...args) => logs.push(args.join(' '));
    console.warn = (...args) => logs.push('⚠️ ' + args.join(' '));
    console.error = (...args) => logs.push('❌ ' + args.join(' '));

    try {
      delete require.cache[require.resolve(filePath)];
      const testModule = require(filePath);
      if (typeof testModule === 'function') {
        await testModule();
      } else if (typeof testModule.run === 'function') {
        await testModule.run();
      } else {
        throw new Error(`Test file ${file} does not export a function or a run() method.`);
      }
      passedCount++;
      originalLog(`✅ [PASSED] ${file}`);
    } catch (err) {
      failedCount++;
      originalLog(`❌ [FAILED] ${file}`);
      originalLog('--- TEST TRACE LOGS ---');
      logs.forEach(l => originalLog(l));
      originalLog(err.stack || err);
      originalLog('-----------------------\n');
    }
  }

  console.log = originalLog;
  console.warn = originalWarn;
  console.error = originalError;

  console.log('\n============================================================');
  console.log(`📊 TEST SONUÇLARI:`);
  console.log(`   Başarılı : ${passedCount}`);
  console.log(`   Hatalı   : ${failedCount}`);
  console.log('============================================================');

  if (failedCount > 0) {
    process.exit(1);
  }
}

runAll();
