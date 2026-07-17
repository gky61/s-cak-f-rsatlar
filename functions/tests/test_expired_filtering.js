const cheerio = require('cheerio');

async function testFiltering() {
  const storeUrl = 'https://indirimkodu.donanimhaber.com/trendyol/';
  const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  try {
    const response = await fetch(storeUrl, {
      headers: { 'User-Agent': userAgent },
      signal: AbortSignal.timeout(10000)
    });
    const html = await response.text();
    
    // 1. Without filtering
    const $1 = cheerio.load(html);
    const countAll = $1('a[data-single*="/kupon/"]').length;
    console.log(`📊 Without filtering: Found ${countAll} coupons in total.`);

    // 2. With filtering
    const $2 = cheerio.load(html);
    const expiredHeading = $2('h2').filter((i, el) => $2(el).text().includes('Geçmiş Kuponlar'));
    if (expiredHeading.length > 0) {
      console.log('🧹 Expired heading found, removing expired coupons...');
      expiredHeading.nextAll().remove();
      expiredHeading.remove();
    } else {
      console.log('⚠️ Expired heading not found.');
    }
    
    const countFiltered = $2('a[data-single*="/kupon/"]').length;
    console.log(`📊 With filtering: Found ${countFiltered} active coupons.`);
    console.log(`Difference: ${countAll - countFiltered} expired coupons filtered out.`);

    // Let's print the first active coupon details
    if (countFiltered > 0) {
      const firstActive = $2('a[data-single*="/kupon/"]').first();
      console.log('Active Coupon Example:', {
        title: firstActive.attr('title'),
        id: firstActive.attr('data-coupon-id'),
        link: firstActive.attr('data-single')
      });
    }

  } catch (err) {
    console.error('Error:', err.message);
  }
}

testFiltering();
