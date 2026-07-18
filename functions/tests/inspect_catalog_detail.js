const cheerio = require('cheerio');

async function inspectCatalog() {
  const listUrl = 'https://www.akakce.com/brosurler/a101';
  const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  try {
    console.log('Fetching list page:', listUrl);
    const listResponse = await fetch(listUrl, {
      headers: { 'User-Agent': userAgent },
      signal: AbortSignal.timeout(10000)
    });
    if (!listResponse.ok) {
      throw new Error(`Failed to fetch list page: ${listResponse.status}`);
    }
    const listHtml = await listResponse.text();
    const $list = cheerio.load(listHtml);
    
    // Find all brochure links
    const links = [];
    $list('a[href^="/brosurler/a101-"]').each((i, el) => {
      const href = $list(el).attr('href');
      if (href && !links.includes(href)) {
        links.push(href);
      }
    });

    console.log(`Found ${links.length} brochure links to inspect.`);

    for (const href of links) {
      const detailUrl = 'https://www.akakce.com' + href;
      console.log(`Fetching detail page: ${detailUrl}`);
      
      const detailResponse = await fetch(detailUrl, {
        headers: { 'User-Agent': userAgent },
        signal: AbortSignal.timeout(10000)
      });
      if (!detailResponse.ok) continue;
      
      const detailHtml = await detailResponse.text();
      const $detail = cheerio.load(detailHtml);
      const imgs = $detail('#BP_W .p img');
      
      if (imgs.length > 1) {
        console.log(`\n🎉 Found a multi-page brochure with ${imgs.length} pages! URL: ${detailUrl}`);
        
        imgs.each((i, el) => {
          const $img = $detail(el);
          console.log(`\nImage #${i + 1}:`);
          console.log('  alt:', $img.attr('alt'));
          console.log('  src:', $img.attr('src'));
          console.log('  data-src:', $img.attr('data-src'));
          console.log('  data-original:', $img.attr('data-original'));
          console.log('  lazy-src:', $img.attr('lazy-src'));
          console.log('  style:', $img.attr('style'));
        });
        
        break; // Stop after finding the first one
      } else {
        console.log(`  (This brochure only has ${imgs.length} page. Skipping...)`);
      }
      
      // Delay to be polite
      await new Promise(resolve => setTimeout(resolve, 200));
    }

  } catch (err) {
    console.error('❌ Error during inspection:', err.message);
  }
}

inspectCatalog();
