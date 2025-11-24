// Deal bildirim testi - Gerçek deal örnekleri ile test

// Mock Firebase Admin (test için)
const mockAdmin = {
  messaging: () => ({
    send: async (message) => {
      console.log('📨 Bildirim gönderildi:');
      console.log('   Topic:', message.topic);
      console.log('   Başlık:', message.notification.title);
      console.log('   Mesaj:', message.notification.body);
      console.log('   Data:', JSON.stringify(message.data, null, 2));
      console.log('');
      return {messageId: 'test-message-id'};
    },
  }),
};

// Kategori ismini ID'ye çevir
function getCategoryId(categoryName) {
  const categoryMap = {
    'Bilgisayar': 'bilgisayar',
    'Mobil Cihazlar': 'mobil_cihazlar',
    'Konsollar ve Oyun': 'konsol_oyun',
    'Ev Elektroniği ve Yaşam': 'ev_elektronigi_yasam',
    'Ağ ve Yazılım': 'ag_yazilim',
  };

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
  if (!categoryName.includes(' - ')) return null;

  const parts = categoryName.split(' - ');
  if (parts.length < 2) return null;

  const subCategoryName = parts.slice(1).join(' - ');
  return subCategoryMap[categoryId][subCategoryName] || null;
}

// Bildirim gönderme fonksiyonu (test için)
async function sendDealNotification(deal, dealId) {
  console.log('🔥 Yeni Deal Bildirimi Testi');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`Deal ID: ${dealId}`);
  console.log(`Başlık: ${deal.title}`);
  console.log(`Mağaza: ${deal.store}`);
  console.log(`Kategori: ${deal.category}`);
  console.log(`Onaylandı: ${deal.isApproved}`);
  console.log('');

  // Sadece onaylanmış fırsatlar için bildirim gönder
  if (!deal.isApproved) {
    console.log('❌ Deal onaylanmadı, bildirim gönderilmedi');
    return;
  }

  const categoryName = deal.category;
  const categoryId = getCategoryId(categoryName);

  if (!categoryId) {
    console.log('❌ Kategori bulunamadı:', categoryName);
    return;
  }

  // Ana kategori bildirimi gönder
  const categoryTopic = `category_${categoryId}`;
  const categoryMessage = {
    notification: {
      title: '🔥 Yeni Fırsat!',
      body: `${deal.title} - ${deal.store}`,
    },
    data: {
      dealId: dealId,
      category: categoryId,
      type: 'category',
    },
    topic: categoryTopic,
  };

  try {
    await mockAdmin.messaging().send(categoryMessage);
    console.log('✅ Kategori bildirimi gönderildi:', categoryTopic);
  } catch (error) {
    console.error('❌ Kategori bildirimi hatası:', error);
  }

  // Alt kategori varsa, alt kategori bildirimi de gönder
  const subCategoryId = getSubCategoryId(categoryName, categoryId);
  if (subCategoryId) {
    const subCategoryTopic = `subcategory_${categoryId}_${subCategoryId}`;
    const subCategoryMessage = {
      notification: {
        title: '🔥 Yeni Fırsat!',
        body: `${deal.title} - ${deal.store}`,
      },
      data: {
        dealId: dealId,
        category: categoryId,
        subCategory: subCategoryId,
        type: 'subcategory',
      },
      topic: subCategoryTopic,
    };

    try {
      await mockAdmin.messaging().send(subCategoryMessage);
      console.log('✅ Alt kategori bildirimi gönderildi:', subCategoryTopic);
    } catch (error) {
      console.error('❌ Alt kategori bildirimi hatası:', error);
    }
  }

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

// Test senaryoları
async function runTests() {
  console.log('🧪 Deal Bildirim Test Senaryoları\n');

  // Test 1: Onaylanmış deal - Bilgisayar - Ekran Kartı
  const deal1 = {
    title: 'RTX 4090 Ekran Kartı',
    store: 'Teknosa',
    category: 'Bilgisayar - Ekran Kartı (GPU)',
    isApproved: true,
  };
  await sendDealNotification(deal1, 'deal-001');

  // Test 2: Onaylanmış deal - Mobil Cihazlar - Cep Telefonu
  const deal2 = {
    title: 'iPhone 15 Pro Max',
    store: 'Apple Store',
    category: 'Mobil Cihazlar - Cep Telefonu (Android, iOS)',
    isApproved: true,
  };
  await sendDealNotification(deal2, 'deal-002');

  // Test 3: Onaylanmamış deal (bildirim gönderilmemeli)
  const deal3 = {
    title: 'Samsung Galaxy S24',
    store: 'Samsung Store',
    category: 'Mobil Cihazlar - Cep Telefonu (Android, iOS)',
    isApproved: false,
  };
  await sendDealNotification(deal3, 'deal-003');

  // Test 4: Onaylanmış deal - Konsol Oyun - Konsollar
  const deal4 = {
    title: 'PlayStation 5',
    store: 'MediaMarkt',
    category: 'Konsollar ve Oyun - Konsollar (PlayStation, Xbox, Nintendo Switch)',
    isApproved: true,
  };
  await sendDealNotification(deal4, 'deal-004');

  // Test 5: Onaylanmış deal - Sadece kategori (alt kategori yok)
  const deal5 = {
    title: 'Genel Bilgisayar Fırsatı',
    store: 'Vatan Bilgisayar',
    category: 'Bilgisayar',
    isApproved: true,
  };
  await sendDealNotification(deal5, 'deal-005');

  console.log('✅ Tüm testler tamamlandı!');
}

// Testleri çalıştır
runTests().catch(console.error);

