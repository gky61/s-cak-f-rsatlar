/**
 * Test: hb.biz kısa link çözümleme stratejileri
 * Hedef: app.hb.biz/XXX → hepsiburada.com/... gerçek ürün URL'sine dönüştürme
 */
const { spawnSync } = require('child_process');

const TEST_URLS = [
  'https://app.hb.biz/ycpwZNyv7dFK',
  'https://app.hb.biz/a5bzztOjKFMB',
  'https://app.hb.biz/RRAGeZnddSrr'
];

async function testAllStrategies() {
  for (const url of TEST_URLS) {
    console.log(`\n${'='.repeat(80)}`);
    console.log(`🔗 Testing: ${url}`);
    console.log('='.repeat(80));

    // Strategy 1: curl -L with WhatsApp UA (like ty.gl resolver)
    console.log('\n--- Strategy 1: curl -sL WhatsApp UA ---');
    try {
      const res = spawnSync('curl', [
        '-sL',
        '-o', 'NUL',
        '-w', '%{url_effective}',
        '-H', 'User-Agent: WhatsApp/2.23.4.15 A',
        '-H', 'Accept-Language: tr-TR,tr;q=0.9',
        '--max-time', '15',
        url
      ], { encoding: 'utf-8', timeout: 18000 });
      console.log(`  Exit code: ${res.status}`);
      console.log(`  Effective URL: ${res.stdout?.trim()}`);
      if (res.stderr) console.log(`  Stderr: ${res.stderr.substring(0, 200)}`);
    } catch (e) {
      console.log(`  Error: ${e.message}`);
    }

    // Strategy 2: curl -sL with Chrome UA
    console.log('\n--- Strategy 2: curl -sL Chrome UA ---');
    try {
      const res = spawnSync('curl', [
        '-sL',
        '-o', 'NUL',
        '-w', '%{url_effective}',
        '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        '-H', 'Accept-Language: tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        '--max-time', '15',
        url
      ], { encoding: 'utf-8', timeout: 18000 });
      console.log(`  Exit code: ${res.status}`);
      console.log(`  Effective URL: ${res.stdout?.trim()}`);
    } catch (e) {
      console.log(`  Error: ${e.message}`);
    }

    // Strategy 3: curl -sI (HEAD request) to get Location header only
    console.log('\n--- Strategy 3: curl -sI HEAD request ---');
    try {
      const res = spawnSync('curl', [
        '-sI',
        '-H', 'User-Agent: WhatsApp/2.23.4.15 A',
        '--max-time', '10',
        url
      ], { encoding: 'utf-8', timeout: 12000 });
      console.log(`  Exit code: ${res.status}`);
      const headers = res.stdout || '';
      const locationMatch = headers.match(/location:\s*(.+)/i);
      if (locationMatch) {
        console.log(`  Location header: ${locationMatch[1].trim()}`);
      } else {
        console.log(`  Headers (first 500 chars):\n${headers.substring(0, 500)}`);
      }
    } catch (e) {
      console.log(`  Error: ${e.message}`);
    }

    // Strategy 4: curl with redirect follow but capture headers too
    console.log('\n--- Strategy 4: curl -sLD- (follow + dump headers) ---');
    try {
      const res = spawnSync('curl', [
        '-sLD-',
        '-o', 'NUL',
        '-H', 'User-Agent: WhatsApp/2.23.4.15 A',
        '-H', 'Accept-Language: tr-TR,tr;q=0.9',
        '--max-time', '15',
        url
      ], { encoding: 'utf-8', timeout: 18000 });
      console.log(`  Exit code: ${res.status}`);
      // Extract all Location headers from redirect chain
      const locations = [];
      const lines = (res.stdout || '').split('\n');
      for (const line of lines) {
        const locMatch = line.match(/^location:\s*(.+)/i);
        if (locMatch) locations.push(locMatch[1].trim());
      }
      if (locations.length > 0) {
        console.log(`  Redirect chain locations:`);
        locations.forEach((loc, i) => console.log(`    ${i + 1}. ${loc}`));
      } else {
        console.log(`  No Location headers found. First 500 chars of output:\n${(res.stdout || '').substring(0, 500)}`);
      }
    } catch (e) {
      console.log(`  Error: ${e.message}`);
    }

    // Strategy 5: Node fetch with redirect: 'manual' to capture Location
    console.log('\n--- Strategy 5: Node fetch redirect:manual ---');
    try {
      const response = await fetch(url, {
        method: 'GET',
        redirect: 'manual',
        headers: {
          'User-Agent': 'WhatsApp/2.23.4.15 A'
        },
        signal: AbortSignal.timeout(10000)
      });
      console.log(`  Status: ${response.status}`);
      console.log(`  Location: ${response.headers.get('location')}`);
      console.log(`  Response URL: ${response.url}`);
    } catch (e) {
      console.log(`  Error: ${e.message}`);
    }

    // Strategy 6: Microlink API
    console.log('\n--- Strategy 6: Microlink API ---');
    try {
      const microRes = await fetch(`https://api.microlink.io/?url=${encodeURIComponent(url)}`, {
        signal: AbortSignal.timeout(15000)
      });
      if (microRes.ok) {
        const data = await microRes.json();
        console.log(`  Resolved URL: ${data.data?.url}`);
        console.log(`  Title: ${data.data?.title}`);
      } else {
        console.log(`  Status: ${microRes.status}`);
      }
    } catch (e) {
      console.log(`  Error: ${e.message}`);
    }

    // Strategy 7: Google Translate Proxy
    console.log('\n--- Strategy 7: Google Translate Proxy ---');
    try {
      const parsedUrl = new URL(url);
      const proxyHost = parsedUrl.hostname.replace(/\./g, '-') + '.translate.goog';
      const translateUrl = `https://${proxyHost}${parsedUrl.pathname}?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;
      console.log(`  Translate URL: ${translateUrl}`);
      const tRes = await fetch(translateUrl, {
        redirect: 'manual',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        },
        signal: AbortSignal.timeout(10000)
      });
      console.log(`  Status: ${tRes.status}`);
      console.log(`  Location: ${tRes.headers.get('location')}`);
    } catch (e) {
      console.log(`  Error: ${e.message}`);
    }
  }
}

testAllStrategies().then(() => {
  console.log('\n\n🏁 All tests completed.');
});
