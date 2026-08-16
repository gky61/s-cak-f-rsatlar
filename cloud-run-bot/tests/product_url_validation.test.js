const { isDomainAllowed, getStoreKeyForUrl, isProductUrl } = require('../domain_allowlist');

function runTests() {
  console.log('🧪 Product URL Path Validation Tests başlatılıyor...\n');

  let passed = 0;
  let failed = 0;
  let total = 0;

  function assert(condition, testName, url, extra = '') {
    total++;
    if (condition) {
      console.log(`  ✅ PASSED: ${testName} → ${url}${extra ? ' ' + extra : ''}`);
      passed++;
    } else {
      console.error(`  ❌ FAILED: ${testName} → ${url}${extra ? ' ' + extra : ''}`);
      failed++;
    }
  }

  // ========================================
  // 1. TRENDYOL
  // ========================================
  console.log('\n--- 1. Trendyol ---');
  // Geçerli ürün URL'leri
  assert(isProductUrl('https://www.trendyol.com/marka/urun-adi-p-12345'), 'Ürün sayfası', 'trendyol.com/marka/urun-adi-p-12345');
  assert(isProductUrl('https://www.trendyol.com/brand/samsung-galaxy-a55-p-823907145'), 'Ürün sayfası (gerçek)', 'trendyol.com/.../samsung-galaxy-a55-p-823907145');
  assert(isProductUrl('https://m.trendyol.com/brand/item-p-999'), 'Mobil ürün sayfası', 'm.trendyol.com/.../item-p-999');
  assert(isProductUrl('https://www.trendyol.com/brand/item-p-999/'), 'Trailing slash', 'trendyol.com/.../item-p-999/');
  assert(isProductUrl('https://www.trendyol.com/brand/item-p-999?boutiqueId=123'), 'Query parametreli', 'trendyol.com/.../item-p-999?boutiqueId=123');
  // Geçersiz URL'ler (kampanya, mağaza, arama)
  assert(!isProductUrl('https://www.trendyol.com/kampanya/teknoloji'), 'Kampanya sayfası', 'trendyol.com/kampanya/teknoloji');
  assert(!isProductUrl('https://www.trendyol.com/sr?q=telefon'), 'Arama sayfası', 'trendyol.com/sr?q=telefon');
  assert(!isProductUrl('https://www.trendyol.com/magaza/apple-m-1234'), 'Mağaza sayfası', 'trendyol.com/magaza/apple-m-1234');
  assert(!isProductUrl('https://www.trendyol.com/'), 'Anasayfa', 'trendyol.com/');

  // ========================================
  // 2. HEPSİBURADA
  // ========================================
  console.log('\n--- 2. Hepsiburada ---');
  assert(isProductUrl('https://www.hepsiburada.com/apple-iphone-15-pro-max-p-HBV00003SJ2Z4'), 'Ürün sayfası', 'hepsiburada.com/...-p-HBV00003SJ2Z4');
  assert(isProductUrl('https://www.hepsiburada.com/samsung-galaxy-s24-pm-HBV00003ABC'), 'PM ürün sayfası', 'hepsiburada.com/...-pm-HBV00003ABC');
  assert(isProductUrl('https://www.hepsiburada.com/urun-p-hbv123abc'), 'Küçük harf', 'hepsiburada.com/urun-p-hbv123abc');
  assert(isProductUrl('https://www.hepsiburada.com/urun-p-hbv123abc/'), 'Trailing slash', 'hepsiburada.com/urun-p-hbv123abc/');
  // Geçersiz
  assert(!isProductUrl('https://www.hepsiburada.com/magaza/samsung'), 'Mağaza sayfası', 'hepsiburada.com/magaza/samsung');
  assert(!isProductUrl('https://www.hepsiburada.com/kampanyalar'), 'Kampanya sayfası', 'hepsiburada.com/kampanyalar');
  assert(!isProductUrl('https://www.hepsiburada.com/ara?q=telefon'), 'Arama sayfası', 'hepsiburada.com/ara?q=telefon');
  assert(!isProductUrl('https://www.hepsiburada.com/'), 'Anasayfa', 'hepsiburada.com/');

  // ========================================
  // 3. AMAZON TR
  // ========================================
  console.log('\n--- 3. Amazon TR ---');
  assert(isProductUrl('https://www.amazon.com.tr/dp/B08N5WRWNW'), 'dp format', 'amazon.com.tr/dp/B08N5WRWNW');
  assert(isProductUrl('https://www.amazon.com.tr/dp/B08N5WRWNW/'), 'dp trailing slash', 'amazon.com.tr/dp/B08N5WRWNW/');
  assert(isProductUrl('https://www.amazon.com.tr/gp/product/B08N5WRWNW'), 'gp/product format', 'amazon.com.tr/gp/product/B08N5WRWNW');
  assert(isProductUrl('https://www.amazon.com.tr/gp/aw/d/B08N5WRWNW'), 'gp/aw/d format', 'amazon.com.tr/gp/aw/d/B08N5WRWNW');
  assert(isProductUrl('https://www.amazon.com.tr/Ürün-Başlık/dp/B08N5WRWNW'), 'Başlıklı dp format', 'amazon.com.tr/Ürün-Başlık/dp/B08N5WRWNW');
  assert(isProductUrl('https://www.amazon.com.tr/dp/B08N5WRWNW?tag=affiliate'), 'Query parametreli', 'amazon.com.tr/dp/B08N5WRWNW?tag=affiliate');
  // Geçersiz
  assert(!isProductUrl('https://www.amazon.com.tr/s?k=telefon'), 'Arama sayfası', 'amazon.com.tr/s?k=telefon');
  assert(!isProductUrl('https://www.amazon.com.tr/deals'), 'Kampanya sayfası', 'amazon.com.tr/deals');
  assert(!isProductUrl('https://www.amazon.com.tr/'), 'Anasayfa', 'amazon.com.tr/');

  // ========================================
  // 4. N11
  // ========================================
  console.log('\n--- 4. N11 ---');
  assert(isProductUrl('https://www.n11.com/urun/samsung-galaxy-a55-12345'), 'Ürün sayfası', 'n11.com/urun/samsung-galaxy-a55-12345');
  assert(isProductUrl('https://www.n11.com/urun/apple-iphone-15-pro-67890/'), 'Trailing slash', 'n11.com/urun/apple-iphone-15-pro-67890/');
  // Geçersiz
  assert(!isProductUrl('https://www.n11.com/arama?promotions=2198503'), 'Kampanya/arama', 'n11.com/arama?promotions=2198503');
  assert(!isProductUrl('https://www.n11.com/magaza/abc'), 'Mağaza sayfası', 'n11.com/magaza/abc');
  assert(!isProductUrl('https://www.n11.com/kampanyalar'), 'Kampanya sayfası', 'n11.com/kampanyalar');
  assert(!isProductUrl('https://www.n11.com/'), 'Anasayfa', 'n11.com/');

  // ========================================
  // 5. PAZARAMA
  // ========================================
  console.log('\n--- 5. Pazarama ---');
  assert(isProductUrl('https://www.pazarama.com/urun-adi-p-abc123'), 'Ürün sayfası', 'pazarama.com/urun-adi-p-abc123');
  assert(isProductUrl('https://www.pazarama.com/urun-p-a1b2c3/'), 'Trailing slash', 'pazarama.com/urun-p-a1b2c3/');
  // Geçersiz
  assert(!isProductUrl('https://www.pazarama.com/kategori/elektronik'), 'Kategori sayfası', 'pazarama.com/kategori/elektronik');
  assert(!isProductUrl('https://www.pazarama.com/'), 'Anasayfa', 'pazarama.com/');

  // ========================================
  // 6. İDEFİX
  // ========================================
  console.log('\n--- 6. İdefix ---');
  assert(isProductUrl('https://www.idefix.com/kitap-adi-p-12345'), 'Ürün sayfası', 'idefix.com/kitap-adi-p-12345');
  assert(isProductUrl('https://www.idefix.com/kitap-adi-p-12345/'), 'Trailing slash', 'idefix.com/kitap-adi-p-12345/');
  // Geçersiz
  assert(!isProductUrl('https://www.idefix.com/kategori/roman'), 'Kategori sayfası', 'idefix.com/kategori/roman');
  assert(!isProductUrl('https://www.idefix.com/'), 'Anasayfa', 'idefix.com/');

  // ========================================
  // 7. PTTAVM
  // ========================================
  console.log('\n--- 7. PTTavm ---');
  assert(isProductUrl('https://www.pttavm.com/urun-p-12345'), 'Ürün sayfası', 'pttavm.com/urun-p-12345');
  assert(isProductUrl('https://www.pttavm.com/urun-p-12345/'), 'Trailing slash', 'pttavm.com/urun-p-12345/');
  // Geçersiz
  assert(!isProductUrl('https://www.pttavm.com/kampanyalar'), 'Kampanya sayfası', 'pttavm.com/kampanyalar');
  assert(!isProductUrl('https://www.pttavm.com/'), 'Anasayfa', 'pttavm.com/');

  // ========================================
  // 8. TEKNOSA
  // ========================================
  console.log('\n--- 8. Teknosa ---');
  assert(isProductUrl('https://www.teknosa.com/apple-iphone-15-p-12345'), 'Ürün sayfası', 'teknosa.com/apple-iphone-15-p-12345');
  assert(isProductUrl('https://www.teknosa.com/apple-iphone-15-p-12345/'), 'Trailing slash', 'teknosa.com/apple-iphone-15-p-12345/');
  // Geçersiz
  assert(!isProductUrl('https://www.teknosa.com/kampanyalar'), 'Kampanya sayfası', 'teknosa.com/kampanyalar');
  assert(!isProductUrl('https://www.teknosa.com/'), 'Anasayfa', 'teknosa.com/');

  // ========================================
  // 9. MEDIAMARKT TR
  // ========================================
  console.log('\n--- 9. MediaMarkt TR ---');
  assert(isProductUrl('https://www.mediamarkt.com.tr/tr/product/_apple-iphone-15-128gb-12345.html'), 'Ürün sayfası (underscore)', 'mediamarkt.com.tr/tr/product/_...-12345.html');
  assert(isProductUrl('https://www.mediamarkt.com.tr/tr/product/apple-iphone-15-128gb-12345.html'), 'Ürün sayfası (underscore yok)', 'mediamarkt.com.tr/tr/product/...-12345.html');
  assert(isProductUrl('https://www.mediamarkt.com.tr/tr/product/_apple-iphone-15-128gb-12345.html/'), 'Trailing slash', 'mediamarkt.com.tr/tr/product/_...-12345.html/');
  // Geçersiz
  assert(!isProductUrl('https://www.mediamarkt.com.tr/tr/category/telefonlar'), 'Kategori sayfası', 'mediamarkt.com.tr/tr/category/telefonlar');
  assert(!isProductUrl('https://www.mediamarkt.com.tr/'), 'Anasayfa', 'mediamarkt.com.tr/');

  // ========================================
  // 10. VATAN BİLGİSAYAR (BYPASS - boş kural)
  // ========================================
  console.log('\n--- 10. Vatan Bilgisayar (BYPASS) ---');
  assert(isProductUrl('https://www.vatanbilgisayar.com/apple-iphone-15/'), 'Herhangi URL (bypass)', 'vatanbilgisayar.com/apple-iphone-15/');
  assert(isProductUrl('https://www.vatanbilgisayar.com/kampanya/xyz'), 'Kampanya bile bypass', 'vatanbilgisayar.com/kampanya/xyz');
  assert(isProductUrl('https://www.vatanbilgisayar.com/'), 'Anasayfa bile bypass', 'vatanbilgisayar.com/');

  // ========================================
  // 11. İTOPYA
  // ========================================
  console.log('\n--- 11. İtopya ---');
  assert(isProductUrl('https://www.itopya.com/apple-macbook-pro_u12345'), 'Ürün sayfası', 'itopya.com/apple-macbook-pro_u12345');
  assert(isProductUrl('https://www.itopya.com/apple-macbook-pro_u12345/'), 'Trailing slash', 'itopya.com/apple-macbook-pro_u12345/');
  // Geçersiz
  assert(!isProductUrl('https://www.itopya.com/bilgisayar'), 'Kategori sayfası', 'itopya.com/bilgisayar');
  assert(!isProductUrl('https://www.itopya.com/'), 'Anasayfa', 'itopya.com/');

  // ========================================
  // 12. İNCEHESAP
  // ========================================
  console.log('\n--- 12. İncehesap ---');
  assert(isProductUrl('https://www.incehesap.com/apple-iphone-15-fiyati-12345'), 'Ürün sayfası', 'incehesap.com/apple-iphone-15-fiyati-12345');
  assert(isProductUrl('https://www.incehesap.com/apple-iphone-15-fiyati-12345/'), 'Trailing slash', 'incehesap.com/apple-iphone-15-fiyati-12345/');
  // Geçersiz
  assert(!isProductUrl('https://www.incehesap.com/cep-telefonu'), 'Kategori sayfası', 'incehesap.com/cep-telefonu');
  assert(!isProductUrl('https://www.incehesap.com/'), 'Anasayfa', 'incehesap.com/');

  // ========================================
  // 13. MAVİ
  // ========================================
  console.log('\n--- 13. Mavi ---');
  assert(isProductUrl('https://www.mavi.com/p/slim-fit-jean'), 'Ürün sayfası', 'mavi.com/p/slim-fit-jean');
  assert(isProductUrl('https://www.mavi.com/p/slim-fit-jean/'), 'Trailing slash', 'mavi.com/p/slim-fit-jean/');
  assert(isProductUrl('https://www.mavi.com/p/slim-fit-jean-1234abc'), 'Alfanümerik', 'mavi.com/p/slim-fit-jean-1234abc');
  // Geçersiz
  assert(!isProductUrl('https://www.mavi.com/erkek-giyim'), 'Kategori sayfası', 'mavi.com/erkek-giyim');
  assert(!isProductUrl('https://www.mavi.com/'), 'Anasayfa', 'mavi.com/');

  // ========================================
  // 14. DEFACTO
  // ========================================
  console.log('\n--- 14. DeFacto ---');
  assert(isProductUrl('https://www.defacto.com.tr/erkek-slim-fit-gomlek-1234567'), 'Ürün sayfası (7 haneli)', 'defacto.com.tr/...-1234567');
  assert(isProductUrl('https://www.defacto.com.tr/kadin-elbise-12345678/'), 'Trailing slash (8 haneli)', 'defacto.com.tr/...-12345678/');
  assert(isProductUrl('https://www.defacto.com.tr/urun-adi-1234567890'), 'Ürün sayfası (10 haneli)', 'defacto.com.tr/...-1234567890');
  // Geçersiz
  assert(!isProductUrl('https://www.defacto.com.tr/erkek-giyim'), 'Kategori sayfası', 'defacto.com.tr/erkek-giyim');
  assert(!isProductUrl('https://www.defacto.com.tr/kampanya-12'), 'Kısa sayı (< 6 hane)', 'defacto.com.tr/kampanya-12');
  assert(!isProductUrl('https://www.defacto.com.tr/'), 'Anasayfa', 'defacto.com.tr/');

  // ========================================
  // 15. ZARA
  // ========================================
  console.log('\n--- 15. Zara ---');
  assert(isProductUrl('https://www.zara.com/tr/tr/deri-ceket-p12345.html'), 'Ürün sayfası', 'zara.com/tr/tr/deri-ceket-p12345.html');
  assert(isProductUrl('https://www.zara.com/tr/tr/deri-ceket-p12345.html/'), 'Trailing slash', 'zara.com/tr/tr/deri-ceket-p12345.html/');
  // Geçersiz
  assert(!isProductUrl('https://www.zara.com/tr/tr/erkek-giyim-l123.html'), 'Kategori sayfası', 'zara.com/tr/tr/erkek-giyim-l123.html');
  assert(!isProductUrl('https://www.zara.com/tr/tr/'), 'Anasayfa', 'zara.com/tr/tr/');

  // ========================================
  // 16. MANGO
  // ========================================
  console.log('\n--- 16. Mango ---');
  assert(isProductUrl('https://shop.mango.com/tr/tr/p/deri-ceket_12345678'), 'Ürün sayfası (underscore)', 'shop.mango.com/tr/tr/p/deri-ceket_12345678');
  assert(isProductUrl('https://shop.mango.com/tr/tr/p/deri-ceket_12345678/'), 'Trailing slash', 'shop.mango.com/tr/tr/p/deri-ceket_12345678/');
  assert(isProductUrl('https://shop.mango.com/tr/tr/p/deri-ceket/12345678/ab/cd'), 'Alternatif format', 'shop.mango.com/tr/tr/p/deri-ceket/12345678/ab/cd');
  assert(isProductUrl('https://shop.mango.com/tr/tr/p/27034409/56/00?utm_source=product-share&utm_medium=social'), 'Share link (ID+color+size)', 'shop.mango.com/tr/tr/p/27034409/56/00');
  assert(isProductUrl('https://shop.mango.com/tr/tr/p/27034409'), 'Direct ID link', 'shop.mango.com/tr/tr/p/27034409');
  assert(isProductUrl('https://shop.mango.com/tr/en/p/27034409/56/00'), 'English TR link', 'shop.mango.com/tr/en/p/27034409/56/00');
  // Geçersiz
  assert(!isProductUrl('https://shop.mango.com/tr/tr/kadin'), 'Kategori sayfası', 'shop.mango.com/tr/tr/kadin');
  assert(!isProductUrl('https://shop.mango.com/tr/tr/search?q=parka'), 'Arama sayfası', 'shop.mango.com/tr/tr/search?q=parka');
  assert(!isProductUrl('https://shop.mango.com/tr/tr/'), 'Anasayfa', 'shop.mango.com/tr/tr/');

  // ========================================
  // 17. BEYMEN
  // ========================================
  console.log('\n--- 17. Beymen ---');
  assert(isProductUrl('https://www.beymen.com/tr/p_urun-adi_12345'), 'Ürün sayfası', 'beymen.com/tr/p_urun-adi_12345');
  assert(isProductUrl('https://www.beymen.com/en/p_product-name_12345'), 'İngilizce', 'beymen.com/en/p_product-name_12345');
  assert(isProductUrl('https://www.beymen.com/tr/p_urun-adi_12345/'), 'Trailing slash', 'beymen.com/tr/p_urun-adi_12345/');
  // Geçersiz
  assert(!isProductUrl('https://www.beymen.com/tr/kadin/giyim'), 'Kategori sayfası', 'beymen.com/tr/kadin/giyim');
  assert(!isProductUrl('https://www.beymen.com/'), 'Anasayfa', 'beymen.com/');

  // ========================================
  // 18. MİGROS
  // ========================================
  console.log('\n--- 18. Migros ---');
  assert(isProductUrl('https://www.migros.com.tr/sut-p-abc123'), 'Ürün sayfası', 'migros.com.tr/sut-p-abc123');
  assert(isProductUrl('https://www.migros.com.tr/sut-p-abc123/'), 'Trailing slash', 'migros.com.tr/sut-p-abc123/');
  // Geçersiz
  assert(!isProductUrl('https://www.migros.com.tr/sut-urunleri-c-12345'), 'Kategori sayfası', 'migros.com.tr/sut-urunleri-c-12345');
  assert(!isProductUrl('https://www.migros.com.tr/'), 'Anasayfa', 'migros.com.tr/');

  // ========================================
  // 19. GETİR
  // ========================================
  console.log('\n--- 19. Getir ---');
  assert(isProductUrl('https://getir.com/urun/coca-cola-abc123'), 'Ürün sayfası', 'getir.com/urun/coca-cola-abc123');
  assert(isProductUrl('https://getir.com/urun/coca-cola-abc123/'), 'Trailing slash', 'getir.com/urun/coca-cola-abc123/');
  assert(isProductUrl('https://getir.com/buyuk/urun/coca-cola-abc123'), 'Büyük ürün sayfası', 'getir.com/buyuk/urun/coca-cola-abc123');
  // Geçersiz
  assert(!isProductUrl('https://getir.com/kategori/icecekler'), 'Kategori sayfası', 'getir.com/kategori/icecekler');
  assert(!isProductUrl('https://getir.com/'), 'Anasayfa', 'getir.com/');

  // ========================================
  // 20. HAVİT TÜRKİYE (BYPASS - boş kural)
  // ========================================
  console.log('\n--- 20. Havit Türkiye (BYPASS) ---');
  assert(isProductUrl('https://www.havitstore.com.tr/urun/kulaklık'), 'Herhangi URL (bypass)', 'havitstore.com.tr/urun/kulaklık');
  assert(isProductUrl('https://www.havitstore.com.tr/kampanya'), 'Kampanya bile bypass', 'havitstore.com.tr/kampanya');
  assert(isProductUrl('https://www.havitstore.com.tr/'), 'Anasayfa bile bypass', 'havitstore.com.tr/');

  // ========================================
  // 21. TANIMSIZ MAĞAZA (BYPASS - product_path_rules'da yok)
  // ========================================
  console.log('\n--- 21. Tanımsız Mağaza (BYPASS - kural yok) ---');
  assert(isProductUrl('https://www.boyner.com.tr/herhangi-sayfa'), 'Boyner (kural tanımsız, bypass)', 'boyner.com.tr/herhangi-sayfa');
  assert(isProductUrl('https://www.ciceksepeti.com/urun/123'), 'Çiçeksepeti (kural tanımsız, bypass)', 'ciceksepeti.com/urun/123');

  // ========================================
  // 22. EDGE CASES
  // ========================================
  console.log('\n--- 22. Edge Cases ---');
  assert(!isProductUrl(''), 'Boş string', '(empty)');
  assert(!isProductUrl(null), 'Null değer', '(null)');
  assert(!isProductUrl(undefined), 'Undefined değer', '(undefined)');
  assert(!isProductUrl('not-a-url'), 'Geçersiz URL', 'not-a-url');
  assert(!isProductUrl('https://www.google.com/search?q=trendyol'), 'Allowlist dışı domain', 'google.com');

  // ========================================
  // SONUÇ
  // ========================================
  console.log(`\n==================================================`);
  console.log(`📊 Product URL Validation Test Sonucu: ${passed}/${total} test geçti!`);
  if (failed > 0) {
    console.error(`❌ ${failed} test BAŞARISIZ!`);
  }
  console.log(`==================================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
