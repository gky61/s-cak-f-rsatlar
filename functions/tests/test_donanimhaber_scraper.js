const cheerio = require('cheerio');

async function testScraping() {
  console.log('🚀 Starting DonanimHaber Scraping Test using native fetch...');
  const storeUrl = 'https://indirimkodu.donanimhaber.com/trendyol/';
  const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  try {
    const response = await fetch(storeUrl, {
      headers: { 'User-Agent': userAgent },
      signal: AbortSignal.timeout(10000)
    });
    
    console.log(`✅ Fetched store page. Status: ${response.status}`);
    const html = await response.text();
    const $ = cheerio.load(html);
    const coupons = [];

    // Find links that have data-single containing "/kupon/"
    $('a[data-single*="/kupon/"]').each((i, el) => {
      const dataSingle = $(el).attr('data-single');
      const dataCouponId = $(el).attr('data-coupon-id');
      const store = $(el).attr('data-store') || 'Trendyol';
      
      if (dataSingle && dataCouponId) {
        coupons.push({
          detailUrl: dataSingle,
          couponId: dataCouponId,
          store: store
        });
      }
    });

    console.log(`Found ${coupons.length} coupons on the Trendyol page.`);
    if (coupons.length === 0) {
      console.log('⚠️ No coupons found. Outputting first 1000 characters of HTML:');
      console.log(html.substring(0, 1000));
      return;
    }

    const testCoupon = coupons[0];
    console.log('🔍 Testing coupon:', testCoupon);

    // Fetch the final URL with _c param
    const finalUrl = `${testCoupon.detailUrl}?_c=${testCoupon.couponId}`;
    console.log(`Fetching detail page: ${finalUrl}`);

    const detailResponse = await fetch(finalUrl, {
      headers: { 'User-Agent': userAgent },
      signal: AbortSignal.timeout(5000)
    });

    console.log(`✅ Fetched detail page. Status: ${detailResponse.status}`);
    const detailHtml = await detailResponse.text();
    const $detail = cheerio.load(detailHtml);

    const title = $detail('meta[property="og:title"]').attr('content') || '';
    const description = $detail('meta[property="og:description"]').attr('content') || '';
    const couponCode = $detail('input#coupon_copy').attr('value') || '';

    console.log('📋 Scraped details:');
    console.log(`- Title: ${title}`);
    console.log(`- Description: ${description}`);
    console.log(`- Code: ${couponCode}`);

  } catch (error) {
    console.error('❌ Scraping error:', error.message);
  }
}

testScraping();
