const { scrapeProductFromUrl } = require('./link_scraper_service');

const urls = [
  'https://www.vatanbilgisayar.com/asus-vivobook-16-3-nesil-core-ultra-5-325-16gb-512gb-ssd-16inc-w11.html',
  'https://www.pazarama.com/kurukahveci-mehmet-efendi-turk-kahvesi-100-gr-x-25-adet-p-8690627021209-25?magaza=kaytika',
  'https://app.hb.biz/zidAXCDC1RFp',
  'https://www.trendyol.com/havit/h652bt-anc-aktif-gurultu-engelleme-kulakustu-kablosuz-kulaklik-p-844976728'
];

async function run() {
  console.log('🧪 Scraper Entegrasyon Testleri Başlatılıyor...');
  
  for (const url of urls) {
    console.log('\n------------------------------------------------------------');
    console.log(`🔍 Test ediliyor: ${url}`);
    
    try {
      const result = await scrapeProductFromUrl(url);
      console.log('📊 SCRAPE SONUCU:');
      console.log(`   URL        : ${result.url}`);
      console.log(`   Başlık     : ${result.title}`);
      console.log(`   Fiyat      : ${result.price} TL`);
      console.log(`   Görsel     : ${result.imageUrl}`);
      console.log(`   Kırıntı    : ${JSON.stringify(result.breadcrumbs)}`);
      
      // Basit doğrulamalar
      if (!result.title) {
        console.error('❌ HATA: Başlık çekilemedi!');
      } else if (!result.price) {
        console.error('❌ HATA: Fiyat çekilemedi!');
      } else if (!result.imageUrl) {
        console.error('❌ HATA: Görsel çekilemedi!');
      } else {
        console.log('✅ BAŞARILI: Başlık, fiyat ve görsel başarıyla çekildi.');
      }
    } catch (err) {
      console.error(`❌ BEKLENMEYEN HATA: ${err.message}`);
    }
  }
}

run();
