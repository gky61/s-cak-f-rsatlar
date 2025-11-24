// Test dosyası - Kategori eşleştirme fonksiyonlarını test eder

// Kategori ismini ID'ye çevir
function getCategoryId(categoryName) {
  const categoryMap = {
    'Bilgisayar': 'bilgisayar',
    'Mobil Cihazlar': 'mobil_cihazlar',
    'Konsollar ve Oyun': 'konsol_oyun',
    'Ev Elektroniği ve Yaşam': 'ev_elektronigi_yasam',
    'Ağ ve Yazılım': 'ag_yazilim',
  };

  // Kategori ismini bul (örn: "Bilgisayar - Ekran Kartı" → "Bilgisayar")
  for (const [name, id] of Object.entries(categoryMap)) {
    if (categoryName.startsWith(name)) {
      return id;
    }
  }
  return null;
}

// Alt kategori ismini ID'ye çevir
function getSubCategoryId(categoryName, categoryId) {
  const subCategoryMap = {
    'bilgisayar': {
      'Ekran Kartı (GPU)': 'ekran_karti',
      'İşlemci (CPU)': 'islemci',
      'Anakart': 'anakart',
      'RAM (Bellek)': 'ram',
      'SSD & Depolama (M.2, SATA, NVMe)': 'ssd_depolama',
      'Güç Kaynağı (PSU)': 'guc_kaynagi',
      'Bilgisayar Kasası': 'kasa',
    },
    'mobil_cihazlar': {
      'Cep Telefonu (Android, iOS)': 'cep_telefonu',
      'Tablet': 'tablet',
      'Akıllı Saat ve Bileklik': 'akilli_saat_bileklik',
      'Mobil Aksesuarlar (Powerbank, Şarj Cihazı, Kılıf)': 'mobil_aksesuarlar',
    },
    'konsol_oyun': {
      'Konsollar (PlayStation, Xbox, Nintendo Switch)': 'konsollar',
      'Oyunlar (Dijital Kod, Kutulu)': 'oyunlar',
      'Abonelik Servisleri (Game Pass, PS Plus)': 'abonelik_servisleri',
      'Konsol Aksesuarları (Gamepad, Direksiyon Seti)': 'konsol_aksesuarlari',
    },
    'ev_elektronigi_yasam': {
      'Televizyon (OLED, QLED, TV Box)': 'televizyon',
      'Akıllı Ev (Robot Süpürge, Aydınlatma)': 'akilli_ev',
      'Kişisel Bakım (Tıraş Makinesi vb.)': 'kisisel_bakim',
      'Hobi (Drone, Kamera)': 'hobi',
    },
    'ag_yazilim': {
      'Ağ Ürünleri (Modem, Router, Mesh)': 'ag_urunleri',
      'Yazılım (İşletim Sistemi, Antivirüs)': 'yazilim',
    },
  };

  if (!subCategoryMap[categoryId]) return null;

  // Alt kategori ismini bul (örn: "Bilgisayar - Ekran Kartı (GPU)" → "Ekran Kartı (GPU)")
  // Eğer kategori adında " - " yoksa, alt kategori yok demektir
  if (!categoryName.includes(' - ')) {
    return null;
  }

  // " - " ile ayır ve ikinci kısmı al (alt kategori adı)
  const parts = categoryName.split(' - ');
  if (parts.length < 2) {
    return null;
  }

  const subCategoryName = parts.slice(1).join(' - '); // Birden fazla " - " olabilir
  return subCategoryMap[categoryId][subCategoryName] || null;
}

// Test senaryoları
console.log('🧪 Kategori Eşleştirme Testleri\n');

// Test 1: Basit kategori
console.log('Test 1: Bilgisayar kategorisi');
const test1 = getCategoryId('Bilgisayar');
console.log(`  Giriş: "Bilgisayar" → Çıkış: "${test1}"`);
console.log(test1 === 'bilgisayar' ? '  ✅ Başarılı' : '  ❌ Başarısız');
console.log('');

// Test 2: Alt kategori ile kategori
console.log('Test 2: Bilgisayar - Ekran Kartı (GPU)');
const test2Category = getCategoryId('Bilgisayar - Ekran Kartı (GPU)');
const test2SubCategory = getSubCategoryId('Bilgisayar - Ekran Kartı (GPU)', test2Category);
console.log(`  Kategori: "${test2Category}"`);
console.log(`  Alt Kategori: "${test2SubCategory}"`);
console.log(test2Category === 'bilgisayar' && test2SubCategory === 'ekran_karti' ? '  ✅ Başarılı' : '  ❌ Başarısız');
console.log('');

// Test 3: Mobil Cihazlar - Cep Telefonu
console.log('Test 3: Mobil Cihazlar - Cep Telefonu (Android, iOS)');
const test3Category = getCategoryId('Mobil Cihazlar - Cep Telefonu (Android, iOS)');
const test3SubCategory = getSubCategoryId('Mobil Cihazlar - Cep Telefonu (Android, iOS)', test3Category);
console.log(`  Kategori: "${test3Category}"`);
console.log(`  Alt Kategori: "${test3SubCategory}"`);
console.log(test3Category === 'mobil_cihazlar' && test3SubCategory === 'cep_telefonu' ? '  ✅ Başarılı' : '  ❌ Başarılı');
console.log('');

// Test 4: Konsol Oyun - Konsollar
console.log('Test 4: Konsollar ve Oyun - Konsollar (PlayStation, Xbox, Nintendo Switch)');
const test4Category = getCategoryId('Konsollar ve Oyun - Konsollar (PlayStation, Xbox, Nintendo Switch)');
const test4SubCategory = getSubCategoryId('Konsollar ve Oyun - Konsollar (PlayStation, Xbox, Nintendo Switch)', test4Category);
console.log(`  Kategori: "${test4Category}"`);
console.log(`  Alt Kategori: "${test4SubCategory}"`);
console.log(test4Category === 'konsol_oyun' && test4SubCategory === 'konsollar' ? '  ✅ Başarılı' : '  ❌ Başarısız');
console.log('');

// Test 5: Bilgisayar - İşlemci (CPU)
console.log('Test 5: Bilgisayar - İşlemci (CPU)');
const test5Category = getCategoryId('Bilgisayar - İşlemci (CPU)');
const test5SubCategory = getSubCategoryId('Bilgisayar - İşlemci (CPU)', test5Category);
console.log(`  Kategori: "${test5Category}"`);
console.log(`  Alt Kategori: "${test5SubCategory}"`);
console.log(test5Category === 'bilgisayar' && test5SubCategory === 'islemci' ? '  ✅ Başarılı' : '  ❌ Başarısız');
console.log('');

// Test 6: Geçersiz kategori
console.log('Test 6: Geçersiz kategori');
const test6 = getCategoryId('Geçersiz Kategori');
console.log(`  Giriş: "Geçersiz Kategori" → Çıkış: "${test6}"`);
console.log(test6 === null ? '  ✅ Başarılı (null döndü)' : '  ❌ Başarısız');
console.log('');

// Test 7: Topic oluşturma testi
console.log('Test 7: Topic oluşturma');
const categoryId = 'bilgisayar';
const subCategoryId = 'ekran_karti';
const categoryTopic = `category_${categoryId}`;
const subCategoryTopic = `subcategory_${categoryId}_${subCategoryId}`;
console.log(`  Kategori Topic: "${categoryTopic}"`);
console.log(`  Alt Kategori Topic: "${subCategoryTopic}"`);
console.log(categoryTopic === 'category_bilgisayar' && subCategoryTopic === 'subcategory_bilgisayar_ekran_karti' ? '  ✅ Başarılı' : '  ❌ Başarısız');
console.log('');

console.log('✅ Tüm testler tamamlandı!');






