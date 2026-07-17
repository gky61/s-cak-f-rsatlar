const cheerio = require('cheerio');

async function inspect() {
  const storeUrl = 'https://indirimkodu.donanimhaber.com/trendyol/';
  const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  try {
    const response = await fetch(storeUrl, {
      headers: { 'User-Agent': userAgent },
      signal: AbortSignal.timeout(10000)
    });
    const html = await response.text();
    const $ = cheerio.load(html);

    // Find the heading
    const heading = $('h2').filter((i, el) => $(el).text().includes('Geçmiş'));
    if (heading.length > 0) {
      console.log('✅ Found heading:', heading.text());
      console.log('Class list:', heading.attr('class'));
      console.log('Parent tag name:', heading.parent().prop('tagName'));
      console.log('Parent class list:', heading.parent().attr('class'));
      
      // Print HTML of the parent to understand structure
      console.log('--- Parent HTML snippet ---');
      const parentHtml = heading.parent().html() || '';
      // Print first 500 characters of parent HTML around the heading
      const idx = parentHtml.indexOf('Geçmiş');
      console.log(parentHtml.substring(Math.max(0, idx - 200), Math.min(parentHtml.length, idx + 800)));
    } else {
      console.log('❌ Heading not found.');
    }
  } catch (err) {
    console.error('Error:', err.message);
  }
}

inspect();
