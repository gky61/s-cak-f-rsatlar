const { detectCategory } = require('./category_detection_service');

const testProducts = [
  {
    name: '1. Xiaomi Redmi Watch 4 Akıllı Saat',
    expectedCategory: 'elektronik',
    expectedSubCategory: 'Telefon & Aksesuarları',
    title: 'Xiaomi Redmi Watch 4 Akıllı Saat - Gümüş',
    breadcrumbs: ['Cep Telefonları ve Aksesuarlar', 'Giyilebilir Teknoloji', 'Akıllı Saatler']
  },
  {
    name: '2. Philips Avent SCD503/00 DECT Bebek Telsizi',
    expectedCategory: 'anne_bebek',
    expectedSubCategory: 'Bebek Odası & Güvenlik',
    title: 'Philips Avent SCD503/00 DECT Bebek Telsizi',
    breadcrumbs: ['Anne, Bebek, Oyuncak', 'Bebek Odası ve Güvenliği', 'Bebek Telsizleri']
  },
  {
    name: '3. Ahlatcı 1 gr 24 Ayar Külçe Altın',
    expectedCategory: 'finans_kampanyalar',
    expectedSubCategory: 'Yatırım & Değerli Metaller',
    title: 'Ahlatcı 1 gr 24 Ayar Külçe Altın',
    breadcrumbs: ['Altın', 'Külçe Altın']
  },
  {
    name: '4. Kaspersky Standard 3 Kullanıcı 1 Yıl',
    expectedCategory: 'dijital_hizmetler',
    expectedSubCategory: 'Abonelik & Yazılım',
    title: 'Kaspersky Standard Antivirüs Lisans Anahtarı 3 Kullanıcı 1 Yıl',
    breadcrumbs: ['Bilgisayar', 'Yazılım', 'Güvenlik ve Antivirüs']
  },
  {
    name: '5. Logitech G G102 Lightsync Gaming Mouse',
    expectedCategory: 'elektronik',
    expectedSubCategory: 'Bilgisayar & Tablet',
    title: 'Logitech G G102 Lightsync Oyuncu Faresi',
    breadcrumbs: ['Bilgisayar', 'Çevre Birimleri', 'Klavye ve Mouse', 'Oyuncu Fareleri']
  },
  {
    name: '6. Gümüşh Gümüş Tek Taş Kadın Kolye',
    expectedCategory: 'moda',
    expectedSubCategory: 'Saat, Aksesuar & Takı',
    title: 'Gümüşh Gümüş Tek Taş Kadın Kolye',
    breadcrumbs: ['Takı, Mücevher ve Aksesuar', 'Kolyeler']
  },
  {
    name: '7. Hardline Whey 3 Matrix 2300 gr Protein Tozu',
    expectedCategory: 'supermarket',
    expectedSubCategory: 'Gıda Ürünleri',
    title: 'Hardline Whey 3 Matrix 2300 gr Çikolatalı Protein Tozu',
    breadcrumbs: ['Sağlık, Diyet ve Sporcu Besinleri', 'Sporcu Besinleri', 'Protein Tozları']
  },
  {
    name: '8. My Valice Mother Smart Bebek Bakım Çantası',
    expectedCategory: 'anne_bebek',
    expectedSubCategory: 'Bebek Arabası & Oto Koltuğu',
    title: 'My Valice Mother Smart Bebek Bakım Çantası',
    breadcrumbs: ['Anne, Bebek, Oyuncak', 'Bebek Bakım', 'Bebek Bakım Çantaları']
  },
  {
    name: '9. Hasbro Monopoly Yollar Kutusuz Kutu Oyunu',
    expectedCategory: 'kitap_hobi',
    expectedSubCategory: 'Kutu Oyunları & Oyuncaklar',
    title: 'Hasbro Monopoly Klasik Yollar Kutusuz Kutu Oyunu',
    breadcrumbs: ['Kitap, Hobi, Müzik', 'Hobi ve Eğlence', 'Kutu Oyunları ve Puzzle']
  },
  {
    name: '10. LEGO Technic McLaren Formula 1 Yarışı Yetişkinler İçin Maket',
    expectedCategory: 'kitap_hobi',
    expectedSubCategory: 'Kutu Oyunları & Oyuncaklar',
    title: 'LEGO Technic McLaren Formula 1 Yarış Arabası Yetişkinler İçin Maket Seti',
    breadcrumbs: ['Yapım Oyuncakları', 'LEGO']
  },
  {
    name: '11. Philips Avent Biberon ve Mama Isıtıcı',
    expectedCategory: 'anne_bebek',
    expectedSubCategory: 'Beslenme & Emzirme',
    title: 'Philips Avent Hızlı Biberon ve Mama Isıtıcı',
    breadcrumbs: ['Anne, Bebek, Oyuncak', 'Bebek Beslenme', 'Biberon Isıtıcılar']
  },
  {
    name: '12. Dometic CoolFreeze Oto Buzdolabı',
    expectedCategory: 'yapi_oto',
    expectedSubCategory: 'Oto Aksesuar & Bakım',
    title: 'Dometic CoolFreeze Kompresörlü Oto Buzdolabı 12V/24V',
    breadcrumbs: ['Oto Aksesuar', 'Oto Dış Aksesuar', 'Oto Buzdolabı']
  },
  {
    name: '13. Xiaomi Yeelight Akıllı Ampul',
    expectedCategory: 'elektronik',
    expectedSubCategory: 'Akıllı Ev & Güvenlik',
    title: 'Xiaomi Yeelight Smart Led Akıllı Ampul',
    breadcrumbs: ['Elektrik, Aydınlatma', 'Aydınlatma', 'Ampuller', 'Akıllı Ampuller']
  },
  {
    name: '14. Harry Potter Çocuk Fantastik Kitabı',
    expectedCategory: 'kitap_hobi',
    expectedSubCategory: 'Kitap & Dergi',
    title: 'Harry Potter ve Felsefe Taşı Yapı Kredi Yayınları',
    breadcrumbs: ['Kitap, Hobi', 'Kitap', 'Edebiyat', 'Fantastik']
  },
  {
    name: '15. Decathlon Yoga ve Pilates Matı',
    expectedCategory: 'spor_outdoor',
    expectedSubCategory: 'Fitness & Kondisyon',
    title: 'Decathlon Nyamba Pilates ve Yoga Matı',
    breadcrumbs: ['Spor Malzemeleri', 'Fitness', 'Pilates Ekipmanları', 'Pilates Matı']
  },
  {
    name: '16. Sebamed Baby Bebek Şampuanı 500 ml',
    expectedCategory: 'kozmetik',
    expectedSubCategory: 'Saç Bakımı',
    title: 'Sebamed Baby Bebek Şampuanı 500 ml',
    breadcrumbs: ['Anne, Bebek', 'Bebek Bakım', 'Bebek Şampuanları']
  },
  {
    name: '17. Duracell Şarj Edilebilir AA Kalem Pil',
    expectedCategory: 'elektronik',
    expectedSubCategory: 'Telefon & Aksesuarları',
    title: 'Duracell AA Şarj Edilebilir Kalem Pil 4\'lü',
    breadcrumbs: ['Elektrikli Ev Aletleri', 'Piller & Şarj Cihazları', 'Şarj Edilebilir Piller']
  },
  {
    name: '18. SteelSeries Arctis Nova 7 Gaming Kulaklık',
    expectedCategory: 'elektronik',
    expectedSubCategory: 'Telefon & Aksesuarları',
    title: 'SteelSeries Arctis Nova 7 Kablosuz Oyuncu Kulaklığı',
    breadcrumbs: ['Bilgisayar', 'Çevre Birimleri', 'Kulaklıklar', 'Oyuncu Kulaklıkları']
  },
  {
    name: '19. Philips Avent Yavaş Akış Biberon Emziği',
    expectedCategory: 'anne_bebek',
    expectedSubCategory: 'Beslenme & Emzirme',
    title: 'Philips Avent Antikolik Yavaş Akış Biberon Emziği',
    breadcrumbs: ['Bebek Bakım', 'Biberon Emzikleri']
  },
  {
    name: '20. Darphane Yeni Tarihli Çeyrek Altın',
    expectedCategory: 'finans_kampanyalar',
    expectedSubCategory: 'Yatırım & Değerli Metaller',
    title: 'Darphane Yeni Tarihli Çeyrek Altın',
    breadcrumbs: ['Altın', 'Çeyrek Altın']
  }
];

let successCount = 0;
let failCount = 0;

console.log('🧪 Kategori Eşleştirme Testleri Başlatılıyor (Node.js)...');

for (const product of testProducts) {
  const result = detectCategory(product.title, product.breadcrumbs);
  const matchedCat = result.categoryId;
  const matchedSub = result.subCategory;

  const isSuccess = matchedCat === product.expectedCategory && matchedSub === product.expectedSubCategory;
  if (isSuccess) {
    successCount++;
    console.log(`✅ [GEÇTİ] ${product.name} -> ${matchedCat} > ${matchedSub}`);
  } else {
    failCount++;
    console.error(`❌ [HATA] ${product.name}`);
    console.error(`   Beklenen: ${product.expectedCategory} > ${product.expectedSubCategory}`);
    console.error(`   Alınan  : ${matchedCat} > ${matchedSub}`);
  }
}

console.log('\n📊 TEST SONUÇLARI:');
console.log(`   Başarılı: ${successCount}`);
console.log(`   Başarısız: ${failCount}`);

if (failCount > 0) {
  process.exit(1);
} else {
  console.log('🎉 Tüm Kategori Testleri Başarıyla Geçti!');
  process.exit(0);
}
