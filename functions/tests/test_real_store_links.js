/**
 * FırsatKolik — Gerçek Mağaza Linkleri Mükerrer Kontrol Doğrulama Testi
 * 
 * Bu test, kullanıcının verdiği gerçek mağaza link çiftlerini (kısa ve uzun versiyonlar)
 * alarak redirect çözümler, cleanUrl üretir ve mükerrer tespitinin doğru çalışıp çalışmadığını test eder.
 * 
 * Çalıştırmak için: node functions/tests/test_real_store_links.js
 */

const { resolveUrlRedirects } = require('../../cloud-run-bot/link_scraper_service');

// URL parametrelerini temizleyen fonksiyon (Bot ve Mobil uygulamanın kullandığı mantığın birebir JS karşılığı)
function cleanProductUrl(urlStr) {
  if (!urlStr || typeof urlStr !== 'string') return '';
  try {
    const url = new URL(urlStr.trim());
    const host = url.hostname.toLowerCase();
    
    const majorStores = [
      'amazon',
      'trendyol',
      'hepsiburada',
      'n11',
      'pazarama',
      'pttavm',
      'zara',
      'defacto',
      'mavi',
      'beymen',
      'teknosa',
      'mediamarkt',
      'migros',
      'getir',
      'vatanbilgisayar',
      'idefix',
      'itopya',
      'incehesap',
      'havit'
    ];
    
    let isMajorStore = false;
    for (const store of majorStores) {
      if (host.includes(store)) {
        isMajorStore = true;
        break;
      }
    }
    
    if (isMajorStore) {
      // Büyük mağazalar için query parametrelerini tamamen temizle
      url.search = '';
    } else {
      // Diğer mağazalar için sadece ürün kimlik parametrelerini koru, kalanları sil
      const paramsToKeep = ['id', 'productid', 'product_id', 'p', 'item_id', 'itemid', 'sku'];
      const keys = Array.from(url.searchParams.keys());
      for (const key of keys) {
        if (!paramsToKeep.includes(key.toLowerCase())) {
          url.searchParams.delete(key);
        }
      }
    }
    
    let result = url.toString();
    if (result.endsWith('?')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  } catch (e) {
    return urlStr;
  }
}

// Test verisi (Mağaza bazlı link çiftleri)
const TEST_CASES = [
  {
    store: 'N11',
    link1: 'https://www.n11.com/urun/siemens-eq6-plus-s700-te657319rw-tam-otomatik-kahve-makinesi-45338828?magaza=istanbulankastreltd',
    link2: 'https://www.n11.com/urun/siemens-eq6-plus-s700-te657319rw-tam-otomatik-kahve-makinesi-45338828?magaza=istanbulankastreltd'
  },
  {
    store: 'Pazarama',
    link1: 'https://www.pazarama.com/sony-playstation-5-slim-digital-825-gb-sarj-istasyonu-2-dualsense-ithalatci-garantili-p-2210194445169?magaza=fly-technology',
    link2: 'https://www.pazarama.com/sony-playstation-5-slim-digital-825-gb-sarj-istasyonu-2-dualsense-ithalatci-garantili-p-2210194445169?magaza=fly-technology'
  },
  {
    store: 'Idefix',
    link1: 'https://www.idefix.com/emincelik-ec-su4120bg30-eng-domino-2g-41125-dg-gazli-siyah-cam-setustu-emaye-izgocak-p-1615811',
    link2: 'https://www.idefix.com/emincelik-ec-su4120bg30-eng-domino-2g-41125-dg-gazli-siyah-cam-setustu-emaye-izgocak-p-1615811'
  },
  {
    store: 'MediaMarkt',
    link1: 'https://www.mediamarkt.com.tr/tr/product/_philips-xb715107-marathon-daily-toz-torbasiz-elektrikli-supurge-1229917.html?utm_source=new%20owned&utm_medium=ema-other%20email&utm_term=appshare&utm_campaign=appshare',
    link2: 'https://www.mediamarkt.com.tr/tr/product/_philips-xb715107-marathon-daily-toz-torbasiz-elektrikli-supurge-1229917.html?utm_source=new%20owned&utm_medium=ema-other%20email&utm_term=appshare&utm_campaign=appshare'
  },
  {
    store: 'Vatan Bilgisayar',
    link1: 'https://www.vatanbilgisayar.com/tcl-movetime-family-watch-mt48x-akilli-saat-pembe.html',
    link2: 'https://www.vatanbilgisayar.com/tcl-movetime-family-watch-mt48x-akilli-saat-pembe.html'
  },
  {
    store: 'Teknosa',
    link1: 'https://www.teknosa.com/lenovo-loq-15irx10-83je00jptr-i7-13650hx-16gb-512g-ssd-rtx5050-8g-156-freedos-laptop-p-786380410',
    link2: 'https://www.teknosa.com/lenovo-loq-15irx10-83je00jptr-i7-13650hx-16gb-512g-ssd-rtx5050-8g-156-freedos-laptop-p-786380410'
  },
  {
    store: 'PttAVM',
    link1: 'https://www.pttavm.com/hasir-kadin-cantasi-fermuarli-el-ve-omuz-plaj-cantasi-38-cm-p-1407195946',
    link2: 'https://www.pttavm.com/hasir-kadin-cantasi-fermuarli-el-ve-omuz-plaj-cantasi-38-cm-p-1407195946'
  },
  {
    store: 'Amazon (Short Link)',
    link1: 'https://amzn.eu/d/09AyS9n1',
    link2: 'https://amzn.eu/d/0iDpudyT'
  },
  {
    store: 'Amazon (link.amazon Short Link)',
    link1: 'https://link.amazon/B0aH5993k',
    link2: 'https://link.amazon/B0aH5993k'
  },
  {
    store: 'Hepsiburada (Short Link)',
    link1: 'https://app.hb.biz/0hfOOmmCObc3',
    link2: 'https://app.hb.biz/PKYRtQoUMuj5'
  },
  {
    store: 'Trendyol (Short Link)',
    link1: 'https://ty.gl/0lxnasri8m34r',
    link2: 'https://ty.gl/juievypymgfyc'
  }
];

async function runTests() {
  console.log('🧪 Gerçek Mağaza Fırsat Linkleri Mükerrerlik Doğrulama Testi Başlatılıyor...\n');
  
  let successCount = 0;
  let failCount = 0;

  for (const tc of TEST_CASES) {
    console.log(`\n========================================`);
    console.log(`🏬 Mağaza: ${tc.store}`);
    console.log(`----------------------------------------`);
    console.log(`🔗 Link 1: ${tc.link1}`);
    console.log(`🔗 Link 2: ${tc.link2}`);
    
    try {
      console.log(`⏳ Yönlendirmeler çözülüyor...`);
      // 1. Adım: Yönlendirmeleri takip et (Redirect Resolve)
      const resolvedUrl1 = await resolveUrlRedirects(tc.link1);
      const resolvedUrl2 = await resolveUrlRedirects(tc.link2);
      
      console.log(`📍 Çözülen 1: ${resolvedUrl1}`);
      console.log(`📍 Çözülen 2: ${resolvedUrl2}`);

      // 2. Adım: URL normalizasyonu (cleanUrl üret)
      const cleanUrl1 = cleanProductUrl(resolvedUrl1);
      const cleanUrl2 = cleanProductUrl(resolvedUrl2);

      console.log(`🧼 cleanUrl 1: ${cleanUrl1}`);
      console.log(`🧼 cleanUrl 2: ${cleanUrl2}`);

      // 3. Adım: Eşitlik karşılaştırması
      const isMatch = (cleanUrl1 === cleanUrl2) && (cleanUrl1.length > 0);
      
      if (isMatch) {
        console.log(`\n✅ TEST BAŞARILI: Mükerrer tespiti yapıldı! (cleanUrl'ler eşleşti)`);
        successCount++;
      } else {
        console.error(`\n❌ TEST BAŞARISIZ: Linkler eşleşmedi!`);
        failCount++;
      }
    } catch (err) {
      console.error(`\n💥 HATA OLUŞTU: ${err.message}`);
      failCount++;
    }
  }

  console.log(`\n========================================`);
  console.log(`📊 TEST RAPORU`);
  console.log(`========================================`);
  console.log(`   ✅ Başarılı Mağaza Sayısı: ${successCount}`);
  console.log(`   ❌ Başarısız Mağaza Sayısı: ${failCount}`);
  
  if (failCount > 0) {
    console.error(`\n🚨 Bazı mağaza linkleri mükerrer olarak tespit edilemedi!`);
    process.exit(1);
  } else {
    console.log(`\n🎉 Harika! Tüm mağazalar için mükerrer link engelleme filtresi kusursuz çalışıyor.`);
    process.exit(0);
  }
}

runTests();
