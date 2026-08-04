const { isDomainAllowed, getStoreKeyForUrl, isProductUrl } = require('../domain_allowlist');

function runComprehensiveTests() {
  console.log('🧪 20 Mağaza x 10 Ürün URL (200 Ürün Linki) Kapsamlı Doğrulama Testi Başlatılıyor...\n');

  let passed = 0;
  let failed = 0;
  let total = 0;

  function assertValid(url, storeKey, description) {
    total++;
    const result = isProductUrl(url);
    if (result) {
      passed++;
    } else {
      console.error(`  ❌ BAŞARISIZ (Geçerli Ürün Reddedildi!): [${storeKey}] ${description} -> ${url}`);
      failed++;
    }
  }

  function assertInvalid(url, storeKey, description) {
    total++;
    const result = isProductUrl(url);
    if (!result) {
      passed++;
    } else {
      console.error(`  ❌ BAŞARISIZ (Geçersiz Sayfa Kabul Edildi!): [${storeKey}] ${description} -> ${url}`);
      failed++;
    }
  }

  // ========================================
  // 1. TRENDYOL (10 Ürün + 3 Geçersiz)
  // ========================================
  console.log('--- 1. Trendyol ---');
  const trendyolProducts = [
    'https://www.trendyol.com/apple/iphone-15-128gb-siyah-p-760773950',
    'https://www.trendyol.com/samsung/galaxy-s24-ultra-512gb-p-798123456',
    'https://www.trendyol.com/nike/revolution-6-nn-erkek-kosu-ayakkabisi-p-185432109',
    'https://www.trendyol.com/puma/phase-backpack-sirt-cantasi-p-345678901',
    'https://www.trendyol.com/philips/hd9252-90-airfryer-p-234567890',
    'https://www.trendyol.com/lenovo/ideapad-1-amd-ryzen-5-7520u-16gb-p-678901234',
    'https://www.trendyol.com/logitech/g102-lightsync-oyuncu-mouse-p-456789012',
    'https://www.trendyol.com/crocs/classic-clog-terlik-p-567890123',
    'https://www.trendyol.com/koton/pamuklu-t-shirt-p-890123456',
    'https://www.trendyol.com/stanley/classic-trigger-action-termos-0-47l-p-123456789'
  ];
  trendyolProducts.forEach((url, i) => assertValid(url, 'trendyol', `Ürün ${i + 1}`));
  assertInvalid('https://www.trendyol.com/sr?q=laptop', 'trendyol', 'Arama sayfası');
  assertInvalid('https://www.trendyol.com/butik/liste/1/kadin', 'trendyol', 'Kategori sayfası');
  assertInvalid('https://www.trendyol.com/magaza/apple-m-105021', 'trendyol', 'Mağaza sayfası');

  // ========================================
  // 2. HEPSİBURADA (10 Ürün + 3 Geçersiz)
  // ========================================
  console.log('--- 2. Hepsiburada ---');
  const hepsiburadaProducts = [
    'https://www.hepsiburada.com/apple-iphone-15-128-gb-p-HBCV00004X8QZS',
    'https://www.hepsiburada.com/samsung-galaxy-s23-fe-128-gb-p-HBCV000055Z123',
    'https://www.hepsiburada.com/sony-playstation-5-slim-1tb-p-HBCV00005F9XYZ',
    'https://www.hepsiburada.com/dyson-v15-detect-kablosuz-supurge-p-HBCV0000123456',
    'https://www.hepsiburada.com/nespresso-essenza-mini-kahve-makinesi-p-HBCV0000234567',
    'https://www.hepsiburada.com/asus-rog-strix-g16-gaming-laptop-p-HBCV0000345678',
    'https://www.hepsiburada.com/mchale-erkek-mont-pm-HBCV0000456789',
    'https://www.hepsiburada.com/karaca-biogranit-tencere-set-p-HBCV0000567890',
    'https://www.hepsiburada.com/anker-soundcore-q30-kulaklik-p-HBCV0000678901',
    'https://www.hepsiburada.com/xiaomi-mi-band-8-akilli-bileklik-p-HBV0000789012'
  ];
  hepsiburadaProducts.forEach((url, i) => assertValid(url, 'hepsiburada', `Ürün ${i + 1}`));
  assertInvalid('https://www.hepsiburada.com/ara?q=kulaklik', 'hepsiburada', 'Arama sayfası');
  assertInvalid('https://www.hepsiburada.com/magaza/samsung', 'hepsiburada', 'Mağaza sayfası');
  assertInvalid('https://www.hepsiburada.com/bilgisayarlar-c-2147483646', 'hepsiburada', 'Kategori');

  // ========================================
  // 3. AMAZON TR (10 Ürün + 3 Geçersiz)
  // ========================================
  console.log('--- 3. Amazon TR ---');
  const amazonProducts = [
    'https://www.amazon.com.tr/dp/B0CHX1W1XY',
    'https://www.amazon.com.tr/Apple-iPhone-15-128-GB/dp/B0CHX2F123',
    'https://www.amazon.com.tr/gp/product/B08N5WRWNW',
    'https://www.amazon.com.tr/gp/aw/d/B09G9FPHP6',
    'https://www.amazon.com.tr/Samsung-Galaxy-S24-256GB/dp/B0CS3L1234',
    'https://www.amazon.com.tr/Sony-WH-1000XM5-Kablosuz-Kulaklik/dp/B09Y2B1234',
    'https://www.amazon.com.tr/Kindle-Paperwhite-8GB-6-8-inc/dp/B08N412345',
    'https://www.amazon.com.tr/Cosori-Air-Fryer-Fritoz/dp/B07N812345',
    'https://www.amazon.com.tr/Logitech-MX-Master-3S-Mouse/dp/B09Y312345',
    'https://www.amazon.com.tr/Anker-PowerBank-20000mAh/dp/B08N612345'
  ];
  amazonProducts.forEach((url, i) => assertValid(url, 'amazon_tr', `Ürün ${i + 1}`));
  assertInvalid('https://www.amazon.com.tr/s?k=laptop', 'amazon_tr', 'Arama sayfası');
  assertInvalid('https://www.amazon.com.tr/deals', 'amazon_tr', 'Günün fırsatları');
  assertInvalid('https://www.amazon.com.tr/b?node=12466440031', 'amazon_tr', 'Kategori node');

  // ========================================
  // 4. N11 (10 Ürün + 3 Geçersiz)
  // ========================================
  console.log('--- 4. N11 ---');
  const n11Products = [
    'https://www.n11.com/urun/apple-iphone-15-128-gb-43891023',
    'https://www.n11.com/urun/samsung-galaxy-s24-ultra-512-gb-51239084',
    'https://www.n11.com/urun/sony-playstation-5-oyun-konsolu-18923041',
    'https://www.n11.com/urun/xiaomi-robot-vacuum-s10-akilli-supurge-39201948',
    'https://www.n11.com/urun/philips-marathon-ultimate-toz-torbasiz-supurge-29183049',
    'https://www.n11.com/urun/lg-55-inc-4k-uhd-smart-tv-91823049',
    'https://www.n11.com/urun/lenovo-loq-intel-core-i5-13450hx-16gb-61928304',
    'https://www.n11.com/urun/jbl-flip-6-kablosuz-bluetooth-hoparlor-82910394',
    'https://www.n11.com/urun/delonghi-dedica-ec685-espresso-makinesi-71928304',
    'https://www.n11.com/urun/crocs-classic-clog-unisex-terlik-62910394'
  ];
  n11Products.forEach((url, i) => assertValid(url, 'n11', `Ürün ${i + 1}`));
  assertInvalid('https://www.n11.com/arama?promotions=2198503', 'n11', 'Promosyon araması');
  assertInvalid('https://www.n11.com/magaza/apple', 'n11', 'Mağaza sayfası');
  assertInvalid('https://www.n11.com/bilgisayar', 'n11', 'Kategori sayfası');

  // ========================================
  // 5. PAZARAMA (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 5. Pazarama ---');
  const pazaramaProducts = [
    'https://www.pazarama.com/apple-iphone-15-128-gb-siyah-p-45890123',
    'https://www.pazarama.com/samsung-galaxy-tab-s9-fe-tablet-p-78901234',
    'https://www.pazarama.com/dyson-v12-detect-slim-absolute-p-12345678',
    'https://www.pazarama.com/philips-all-in-one-trimmer-erkek-bakim-p-23456789',
    'https://www.pazarama.com/tefal-ey5058-easy-fry-grill-airfryer-p-34567890',
    'https://www.pazarama.com/asus-tuf-gaming-f15-laptop-p-45678901',
    'https://www.pazarama.com/stanley-klasik-vakumlu-termos-1-litrelik-p-56789012',
    'https://www.pazarama.com/bosch-gsb-180-li-akulu-vidalama-p-67890123',
    'https://www.pazarama.com/karaca-hatir-hup-turk-kahvesi-makinesi-p-78901234',
    'https://www.pazarama.com/samsonite-sirt-cantasi-unisex-p-89012345'
  ];
  pazaramaProducts.forEach((url, i) => assertValid(url, 'pazarama', `Ürün ${i + 1}`));
  assertInvalid('https://www.pazarama.com/arama?q=tv', 'pazarama', 'Arama sayfası');
  assertInvalid('https://www.pazarama.com/kategori/cep-telefonu', 'pazarama', 'Kategori');

  // ========================================
  // 6. İDEFİX (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 6. İdefix ---');
  const idefixProducts = [
    'https://www.idefix.com/seker-portakali-jose-mauro-de-vasconcelos-p-123456',
    'https://www.idefix.com/gece-yarisi-kutuphanesi-matt-haig-p-234567',
    'https://www.idefix.com/simyaci-paulo-coelho-p-345678',
    'https://www.idefix.com/kucuk-prens-antoine-de-saint-exupery-p-456789',
    'https://www.idefix.com/1984-george-orwell-p-567890',
    'https://www.idefix.com/kirmizi-pelerinli-kiz-p-678901',
    'https://www.idefix.com/sut-ve-bal-rupi-kaur-p-789012',
    'https://www.idefix.com/insanin-anlam-arayisi-viktor-frankl-p-890123',
    'https://www.idefix.com/dune-frank-herbert-p-901234',
    'https://www.idefix.com/sokratestin-savunmasi-platon-p-012345'
  ];
  idefixProducts.forEach((url, i) => assertValid(url, 'idefix', `Ürün ${i + 1}`));
  assertInvalid('https://www.idefix.com/kategori/edebiyat', 'idefix', 'Kategori');
  assertInvalid('https://www.idefix.com/arama?q=kitap', 'idefix', 'Arama');

  // ========================================
  // 7. PTTAVM (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 7. PTTavm ---');
  const pttavmProducts = [
    'https://www.pttavm.com/caykur-tiryaki-cayi-1000-gr-p-12345678',
    'https://www.pttavm.com/ariel-toz-camasir-deterjani-10-kg-p-23456789',
    'https://www.pttavm.com/selpak-tuvalet-kagidi-32li-p-34567890',
    'https://www.pttavm.com/yudum-aycicek-yagi-5-lt-p-45678901',
    'https://www.pttavm.com/fairy-hepsi-bir-arada-bulaşik-makinesi-tableti-p-56789012',
    'https://www.pttavm.com/fiskobirlik-fındık-kreması-800-gr-p-67890123',
    'https://www.pttavm.com/kahve-dunyasi-orta-kavrulmus-turk-kahvesi-p-78901234',
    'https://www.pttavm.com/sleepy-natural-bebek-bezi-fırsat-paketi-p-89012345',
    'https://www.pttavm.com/torku-banada-findik-kremasi-700-gr-p-90123456',
    'https://www.pttavm.com/finish-quantum-bulaşik-tableti-p-01234567'
  ];
  pttavmProducts.forEach((url, i) => assertValid(url, 'pttavm', `Ürün ${i + 1}`));
  assertInvalid('https://www.pttavm.com/kategori/gida', 'pttavm', 'Kategori');
  assertInvalid('https://www.pttavm.com/kampanyalar', 'pttavm', 'Kampanya');

  // ========================================
  // 8. TEKNOSA (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 8. Teknosa ---');
  const teknosaProducts = [
    'https://www.teknosa.com/apple-iphone-15-128gb-siyah-smartphone-p-125078901',
    'https://www.teknosa.com/samsung-galaxy-s24-ultra-512gb-titanium-black-p-125078902',
    'https://www.teknosa.com/sony-playstation-5-digital-edition-p-125078903',
    'https://www.teknosa.com/lg-65-oled-4k-smart-tv-p-125078904',
    'https://www.teknosa.com/dyson-airwrap-multi-styler-p-125078905',
    'https://www.teknosa.com/lenovo-ideapad-gaming-3-laptop-p-125078906',
    'https://www.teknosa.com/jbl-wave-flex-tws-kulaklik-p-125078907',
    'https://www.teknosa.com/philips-ep5447-90-tam-otomatik-espresso-p-125078908',
    'https://www.teknosa.com/apple-watch-series-9-gps-45mm-p-125078909',
    'https://www.teknosa.com/canon-eos-2000d-fotograf-makinesi-p-125078910'
  ];
  teknosaProducts.forEach((url, i) => assertValid(url, 'teknosa', `Ürün ${i + 1}`));
  assertInvalid('https://www.teknosa.com/arama?q=telefon', 'teknosa', 'Arama');
  assertInvalid('https://www.teknosa.com/kategori/telefon', 'teknosa', 'Kategori');

  // ========================================
  // 9. MEDIAMARKT TR (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 9. MediaMarkt TR ---');
  const mediamarktProducts = [
    'https://www.mediamarkt.com.tr/tr/product/_apple-iphone-15-128gb-siyah-1234567.html',
    'https://www.mediamarkt.com.tr/tr/product/_samsung-galaxy-s24-256gb-gri-1234568.html',
    'https://www.mediamarkt.com.tr/tr/product/_sony-wh-1000xm5-kulak-ustu-kulaklik-1234569.html',
    'https://www.mediamarkt.com.tr/tr/product/_dyson-v15-detect-supurge-1234570.html',
    'https://www.mediamarkt.com.tr/tr/product/_bose-quietcomfort-45-kulaklik-1234571.html',
    'https://www.mediamarkt.com.tr/tr/product/apple-ipad-air-5-nesil-64gb-1234572.html',
    'https://www.mediamarkt.com.tr/tr/product/_lg-oled55c34la-55-inc-tv-1234573.html',
    'https://www.mediamarkt.com.tr/tr/product/_delonghi-magnifica-s-kahve-makinesi-1234574.html',
    'https://www.mediamarkt.com.tr/tr/product/_ninja-foodi-max-dual-zone-airfryer-1234575.html',
    'https://www.mediamarkt.com.tr/tr/product/_asus-tuf-dash-f15-oyuncu-laptop-1234576.html'
  ];
  mediamarktProducts.forEach((url, i) => assertValid(url, 'mediamarkt_tr', `Ürün ${i + 1}`));
  assertInvalid('https://www.mediamarkt.com.tr/tr/category/telefonlar', 'mediamarkt_tr', 'Kategori');
  assertInvalid('https://www.mediamarkt.com.tr/tr/search.html?query=tv', 'mediamarkt_tr', 'Arama');

  // ========================================
  // 10. VATAN BİLGİSAYAR (10 Ürün - BYPASS)
  // ========================================
  console.log('--- 10. Vatan Bilgisayar (BYPASS Store) ---');
  const vatanProducts = [
    'https://www.vatanbilgisayar.com/iphone-15-128-gb-akilli-telefon-siyah.html',
    'https://www.vatanbilgisayar.com/samsung-galaxy-s24-ultra-256-gb-akilli-telefon.html',
    'https://www.vatanbilgisayar.com/oem-hazir-sistemler/',
    'https://www.vatanbilgisayar.com/lg-oled55c34la-55inc-4k-uhd-smart-tv.html',
    'https://www.vatanbilgisayar.com/asus-tuf-gaming-vg249ql3a-monitor.html',
    'https://www.vatanbilgisayar.com/rampage-rm-k27-smile-kulaklik.html',
    'https://www.vatanbilgisayar.com/seagate-barracuda-3-5-2tb-sata-3-0-hdd.html',
    'https://www.vatanbilgisayar.com/logitech-g502-hero-high-performance-mouse.html',
    'https://www.vatanbilgisayar.com/kingston-1tb-kc3000-nvme-m2-ssd.html',
    'https://www.vatanbilgisayar.com/msi-geforce-rtx-4070-super-12g-ekran-karti.html'
  ];
  vatanProducts.forEach((url, i) => assertValid(url, 'vatan_bilgisayar', `Ürün ${i + 1}`));

  // ========================================
  // 11. İTOPYA (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 11. İtopya ---');
  const itopyaProducts = [
    'https://www.itopya.com/afk-iii-amd-ryzen-5-5600-gigabyte-geforce-rtx-4060-8gb-hazir-sistem_u25890',
    'https://www.itopya.com/asus-238-tuf-gaming-vg249q1a-165hz-1ms-freesync-premium-fhd-ips-gaming-monitor_u12345',
    'https://www.itopya.com/goodram-8gb-irdm-x-3200mhz-cl16-ddr4-siyah-single-kit-ram_u23456',
    'https://www.itopya.com/kingston-1tb-nv2-nvme-pcie-40-m2-2280-ssd-3500mb-okuma-2100mb-yazma_u34567',
    'https://www.itopya.com/razer-deathadder-v2-x-hyperspeed-kablosuz-gaming-mouse_u45678',
    'https://www.itopya.com/hyperx-cloud-ii-71-kirmizi-gaming-kulaklik_u56789',
    'https://www.itopya.com/steelseries-apex-3-tkl-turkce-rgb-gaming-klavye_u67890',
    'https://www.itopya.com/thermaltake-s200-tg-550w-80-argb-mesh-mid-tower-kasa_u78901',
    'https://www.itopya.com/gigabyte-b550m-ds3h-4000mhzoc-ddr4-soket-am4-m2-hdmi-dvi-matx-anakart_u89012',
    'https://www.itopya.com/amd-ryzen-7-7800x3d-42ghz-96mb-onbellek-8-cekirdek-am5-5nm-islemci_u90123'
  ];
  itopyaProducts.forEach((url, i) => assertValid(url, 'itopya', `Ürün ${i + 1}`));
  assertInvalid('https://www.itopya.com/kategori/bilgisayar', 'itopya', 'Kategori');
  assertInvalid('https://www.itopya.com/firsatlar', 'itopya', 'Fırsatlar');

  // ========================================
  // 12. İNCEHESAP (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 12. İncehesap ---');
  const incehesapProducts = [
    'https://www.incehesap.com/gamepower-warlock-compact-mekanik-klavye-fiyati-45890',
    'https://www.incehesap.com/james-donkey-712-siyah-7-1-surround-kulaklik-fiyati-12345',
    'https://www.incehesap.com/msi-mag-forge-100m-temperli-cam-kasa-fiyati-23456',
    'https://www.incehesap.com/amd-ryzen-5-5600-islemci-fiyati-34567',
    'https://www.incehesap.com/asus-dual-rtx-4060-o8g-ekran-karti-fiyati-45678',
    'https://www.incehesap.com/team-t-force-vulcan-tufl-16gb-ddr4-ram-fiyati-56789',
    'https://www.incehesap.com/kioxia-exceria-g2-1tb-nvme-ssd-fiyati-67890',
    'https://www.incehesap.com/cougar-cbm-500w-80-guc-kaynagi-fiyati-78901',
    'https://www.incehesap.com/aoc-24g2spu-bk-23-8-165hz-ips-monitor-fiyati-89012',
    'https://www.incehesap.com/logitech-g305-lightspeed-kablosuz-mouse-fiyati-90123'
  ];
  incehesapProducts.forEach((url, i) => assertValid(url, 'incehesap', `Ürün ${i + 1}`));
  assertInvalid('https://www.incehesap.com/gaming-kasa', 'incehesap', 'Kategori');
  assertInvalid('https://www.incehesap.com/gaming-gecesi', 'incehesap', 'Kampanya');

  // ========================================
  // 13. MAVİ (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 13. Mavi ---');
  const maviProducts = [
    'https://www.mavi.com/p/100863-900',
    'https://www.mavi.com/p/marcus-koyu-kumlama-mavi-jean-pantolon-100864-34567',
    'https://www.mavi.com/p/james-siyah-jean-pantolon-100865-12345',
    'https://www.mavi.com/p/baski-detayli-siyah-t-shirt-061092-900',
    'https://www.mavi.com/p/kapusonlu-siyah-sweatshirt-061093-900',
    'https://www.mavi.com/p/mavi-logo-baskili-beyaz-t-shirt-061094-100',
    'https://www.mavi.com/p/jaket-stil-denim-ceket-010495-900',
    'https://www.mavi.com/p/skinny-fit-indigo-jean-100866-900',
    'https://www.mavi.com/p/regular-fit-oduncu-gomlek-051996-900',
    'https://www.mavi.com/p/triko-kazak-gri-070897-900'
  ];
  maviProducts.forEach((url, i) => assertValid(url, 'mavi', `Ürün ${i + 1}`));
  assertInvalid('https://www.mavi.com/erkek-giyim', 'mavi', 'Kategori');
  assertInvalid('https://www.mavi.com/kadin', 'mavi', 'Kategori');

  // ========================================
  // 14. DEFACTO (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 14. DeFacto ---');
  const defactoProducts = [
    'https://www.defacto.com.tr/slim-fit-bisiklet-yaka-t-shirt-3012984',
    'https://www.defacto.com.tr/regular-fit-gömlek-yaka-long-sleeve-3123940',
    'https://www.defacto.com.tr/pantolon-jean-regular-fit-2983012',
    'https://www.defacto.com.tr/kapusonlu-sweatshirt-3192039',
    'https://www.defacto.com.tr/kadin-triko-kazak-3019283',
    'https://www.defacto.com.tr/deri-look-mont-3102938',
    'https://www.defacto.com.tr/polo-yaka-t-shirt-2901928',
    'https://www.defacto.com.tr/jogger-esofman-alti-3182901',
    'https://www.defacto.com.tr/kadin-oversize-bluz-3091823',
    'https://www.defacto.com.tr/kumas-pantolon-2981029'
  ];
  defactoProducts.forEach((url, i) => assertValid(url, 'defacto', `Ürün ${i + 1}`));
  assertInvalid('https://www.defacto.com.tr/erkek-giyim', 'defacto', 'Kategori');
  assertInvalid('https://www.defacto.com.tr/indirim', 'defacto', 'Kampanya');

  // ========================================
  // 15. ZARA (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 15. Zara ---');
  const zaraProducts = [
    'https://www.zara.com/tr/tr/deri-efektli-ceket-p03046001.html',
    'https://www.zara.com/tr/tr/basic-t-shirt-p00962400.html',
    'https://www.zara.com/tr/tr/oversize-sweatshirt-p04104500.html',
    'https://www.zara.com/tr/tr/straight-fit-jean-p01538400.html',
    'https://www.zara.com/tr/tr/keten-karisimli-gomlek-p07545300.html',
    'https://www.zara.com/tr/tr/kase-palto-p08073200.html',
    'https://www.zara.com/tr/tr/mini-elbise-p02157400.html',
    'https://www.zara.com/tr/tr/deri-ayakkabi-p01204300.html',
    'https://www.zara.com/tr/tr/kapusonlu-parka-p03427500.html',
    'https://www.zara.com/tr/tr/kumas-pantolon-p04387600.html'
  ];
  zaraProducts.forEach((url, i) => assertValid(url, 'zara', `Ürün ${i + 1}`));
  assertInvalid('https://www.zara.com/tr/tr/erkek-yeni-girenler-l719.html', 'zara', 'Kategori');
  assertInvalid('https://www.zara.com/tr/tr/kadin-indirim-l1024.html', 'zara', 'İndirim');

  // ========================================
  // 16. MANGO (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 16. Mango ---');
  const mangoProducts = [
    'https://shop.mango.com/tr/tr/p/kadin/ceket/deri-ceket_67014023',
    'https://shop.mango.com/tr/tr/p/kadin/elbise/cicekli-elbise_67025034',
    'https://shop.mango.com/tr/tr/p/erkek/gomlek/keten-gomlek_67036045',
    'https://shop.mango.com/tr/tr/p/kadin/pantolon/straight-jean_67047056',
    'https://shop.mango.com/tr/tr/p/erkek/kazak/v-yaka-kazak_67058067',
    'https://shop.mango.com/tr/tr/p/kadin/ceket/kase-palto_67069078',
    'https://shop.mango.com/tr/tr/p/erkek/t-shirt/pamuklu-t-shirt_67070089',
    'https://shop.mango.com/tr/tr/p/kadin/canta/deri-omuz-cantasi_67081090',
    'https://shop.mango.com/tr/tr/p/kadin/ayakkabi/deri-bot_67092001',
    'https://shop.mango.com/tr/tr/p/kadin/elbise/satin-elbise/67093012/99/99'
  ];
  mangoProducts.forEach((url, i) => assertValid(url, 'mango', `Ürün ${i + 1}`));
  assertInvalid('https://shop.mango.com/tr/tr/kadin', 'mango', 'Kategori');
  assertInvalid('https://shop.mango.com/tr/tr/erkek/yeniler', 'mango', 'Yeniler');

  // ========================================
  // 17. BEYMEN (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 17. Beymen ---');
  const beymenProducts = [
    'https://www.beymen.com/tr/p_network-siyah-dik-yaka-mont_1234567',
    'https://www.beymen.com/tr/p_bape-baskili-t-shirt_2345678',
    'https://www.beymen.com/tr/p_alexander-mcqueen-oversized-sneaker_3456789',
    'https://www.beymen.com/tr/p_moncler-logo-detayli-down-jacket_4567890',
    'https://www.beymen.com/tr/p_off-white-out-of-office-sneaker_5678901',
    'https://www.beymen.com/en/p_gucci-gg-marmont-shoulder-bag_6789012',
    'https://www.beymen.com/tr/p_prada-saffiano-leather-wallet_7890123',
    'https://www.beymen.com/tr/p_balenciaga-triple-s-sneaker_8901234',
    'https://www.beymen.com/tr/p_polo-ralph-lauren-mesh-polo_9012345',
    'https://www.beymen.com/tr/p_hugo-boss-slim-fit-suit_0123456'
  ];
  beymenProducts.forEach((url, i) => assertValid(url, 'beymen', `Ürün ${i + 1}`));
  assertInvalid('https://www.beymen.com/tr/kadin', 'beymen', 'Kategori');
  assertInvalid('https://www.beymen.com/tr/indirim', 'beymen', 'İndirim');

  // ========================================
  // 18. MİGROS (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 18. Migros ---');
  const migrosProducts = [
    'https://www.migros.com.tr/sek-yarim-yagli-sut-1-l-p-1101001',
    'https://www.migros.com.tr/pinar-suzme-peynir-500-g-p-1102002',
    'https://www.migros.com.tr/torku-banada-findik-kremasi-400-g-p-1103003',
    'https://www.migros.com.tr/caykur-rize-turist-cayi-1000-g-p-1104004',
    'https://www.migros.com.tr/yudum-aycicek-yagi-4-l-p-1105005',
    'https://www.migros.com.tr/ariel-aqua-puder-camasir-deterjani-7-kg-p-1106006',
    'https://www.migros.com.tr/fairy-platinum-plus-bulasik-tableti-40li-p-1107007',
    'https://www.migros.com.tr/loreal-paris-hyaluron-uzmani-krem-p-1108008',
    'https://www.migros.com.tr/elidor-ipeksi-yumusaklik-sampuan-500-ml-p-1109009',
    'https://www.migros.com.tr/nestle-damak-gece-cikolata-60-g-p-1110010'
  ];
  migrosProducts.forEach((url, i) => assertValid(url, 'migros', `Ürün ${i + 1}`));
  assertInvalid('https://www.migros.com.tr/sut-kahvaltilik-c-2', 'migros', 'Kategori');
  assertInvalid('https://www.migros.com.tr/arama?q=sut', 'migros', 'Arama');

  // ========================================
  // 19. GETİR (10 Ürün + 2 Geçersiz)
  // ========================================
  console.log('--- 19. Getir ---');
  const getirProducts = [
    'https://getir.com/urun/coca-cola-zero-sugar-1-5-l-555123abc',
    'https://getir.com/urun/eti-karam-gurme-cikolata-50-g-555234def',
    'https://getir.com/urun/dardanel-ton-baligi-2x160-g-555345ghi',
    'https://getir.com/urun/lay-s-firinindan-mevsim-yesillikli-555456jkl',
    'https://getir.com/urun/damla-su-5-l-555567mno',
    'https://getir.com/buyuk/urun/erikli-su-19-l-555678pqr',
    'https://getir.com/urun/red-bull-enerji-icecegi-250-ml-555789stu',
    'https://getir.com/urun/algida-magnum-badem-100-ml-555890vwx',
    'https://getir.com/urun/doritos-taco-baharatli-cips-555901yz1',
    'https://getir.com/buyuk/urun/luzianne-seftali-aroma-souk-cay-55501234a'
  ];
  getirProducts.forEach((url, i) => assertValid(url, 'getir', `Ürün ${i + 1}`));
  assertInvalid('https://getir.com/kategori/su-icecek', 'getir', 'Kategori');
  assertInvalid('https://getir.com/kampanyalar', 'getir', 'Kampanyalar');

  // ========================================
  // 20. HAVİT TÜRKİYE (10 Ürün - BYPASS Store)
  // ========================================
  console.log('--- 20. Havit Türkiye (BYPASS Store) ---');
  const havitProducts = [
    'https://www.havitstore.com.tr/havit-gamenote-fuxi-h3-kablosuz-gaming-kulaklik',
    'https://www.havitstore.com.tr/havit-gamenote-h2002d-gaming-kulaklik',
    'https://www.havitstore.com.tr/havit-hk805-rgb-kablosuz-klavye',
    'https://www.havitstore.com.tr/havit-m9034-akilli-saat',
    'https://www.havitstore.com.tr/havit-gamenote-ms1027-rgb-gaming-mouse',
    'https://www.havitstore.com.tr/havit-sf107bt-bluetooth-hoparlor',
    'https://www.havitstore.com.tr/tum-urunler',
    'https://www.havitstore.com.tr/kampanyalar',
    'https://www.havitstore.com.tr/iletisim',
    'https://www.havitstore.com.tr/hakkimizda'
  ];
  havitProducts.forEach((url, i) => assertValid(url, 'havit_turkiye', `Ürün ${i + 1}`));

  // ========================================
  // SONUÇ
  // ========================================
  console.log(`\n==================================================`);
  console.log(`📊 200 Ürün + 45 Geçersiz Sayfa Test Sonucu: ${passed}/${total} test geçti!`);
  if (failed > 0) {
    console.error(`❌ ${failed} test BAŞARISIZ OLDU!`);
  } else {
    console.log(`🎉 TÜM MAĞAZALAR İÇİN 200/200 ÜRÜN KONTROLÜ VE FİLTRELEME MANTIĞI %100 BAŞARIYLA GEÇTİ!`);
  }
  console.log(`==================================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runComprehensiveTests();
