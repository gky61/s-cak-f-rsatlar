import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/services/deal_search_engine.dart';

Deal createMockDeal({
  required String id,
  required String title,
  required String description,
  required double price,
  required double originalPrice,
  required String category,
  required String store,
  String? brand,
  String? subCategory,
  String? couponCode,
  String? priceLabel,
  DateTime? createdAt,
}) {
  return Deal(
    id: id,
    title: title,
    description: description,
    price: price,
    originalPrice: originalPrice,
    category: category,
    subCategory: subCategory,
    store: store,
    brand: brand,
    couponCode: couponCode,
    priceLabel: priceLabel,
    imageUrl: 'https://example.com/img.jpg',
    hotVotes: 0,
    coldVotes: 0,
    commentCount: 0,
    isEditorPick: false,
    postedBy: 'bot_test',
    link: 'https://example.com/$id',
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  group('Smart Search Engine - 30 Case Benchmark & %90+ Accuracy Test', () {
    late List<Deal> mockDeals;

    setUp(() {
      final now = DateTime.now();

      mockDeals = [
        // ==========================================
        // SEVİYE 1: 10 BASİT / KISA İSİMLİ DUMMY ÜRÜN
        // ==========================================
        createMockDeal(
          id: 'b1',
          title: 'Çaykur Rize Turist Çayı 1000 gr',
          description: 'Siyah paket dökme çay 1 kg paket fırsatı',
          price: 135.0,
          originalPrice: 160.0,
          category: 'supermarket',
          store: 'Migros',
          brand: 'Çaykur',
          createdAt: now,
        ),
        createMockDeal(
          id: 'b2',
          title: 'Apple iPhone 15 128GB Siyah',
          description: 'A16 Bionic çipli akıllı telefon',
          price: 49999.0,
          originalPrice: 53999.0,
          category: 'elektronik',
          store: 'Amazon',
          brand: 'Apple',
          createdAt: now,
        ),
        createMockDeal(
          id: 'b3',
          title: 'Torku Banada Kakaolu Fındık Kreması Şekerli 700g',
          description: 'Lezzetli kahvaltılık fındıklı çikolata ve şeker kreması',
          price: 95.0,
          originalPrice: 120.0,
          category: 'supermarket',
          store: 'Carrefour',
          brand: 'Torku',
          createdAt: now,
        ),
        createMockDeal(
          id: 'b4',
          title: 'Samsung 55 İnc 4K Ultra HD Smart LED TV',
          description: '55 AU7000 model televizyon indirimi',
          price: 18999.0,
          originalPrice: 22000.0,
          category: 'elektronik',
          store: 'Trendyol',
          brand: 'Samsung',
          createdAt: now,
        ),
        createMockDeal(
          id: 'b5',
          title: 'Elidor Güçlü ve Parlak Şampuan 500ml',
          description: 'Saç bakım şampuanı tekli paket',
          price: 65.0,
          originalPrice: 90.0,
          category: 'kozmetik',
          store: 'Watsons',
          brand: 'Elidor',
          createdAt: now,
        ),
        createMockDeal(
          id: 'b6',
          title: 'Sütaş Tam Yağlı Süt 1 Litre 4lü Paket',
          description: 'Taze meralardan lezzetli UHT süt',
          price: 110.0,
          originalPrice: 130.0,
          category: 'supermarket',
          store: 'A101',
          brand: 'Sütaş',
          createdAt: now,
        ),
        createMockDeal(
          id: 'b7',
          title: 'Puma Unisex Siyah Spor Ayakkabı',
          description: 'Günlük koşu ve yürüyüş ayakkabısı',
          price: 1499.0,
          originalPrice: 2199.0,
          category: 'moda',
          store: 'Hepsiburada',
          brand: 'Puma',
          createdAt: now,
        ),
        createMockDeal(
          id: 'b8',
          title: 'Lenovo IdeaPad Slim 3 Laptop',
          description: 'Ryzen 5 7520U 8GB RAM 512GB SSD bilgisayar',
          price: 12499.0,
          originalPrice: 14500.0,
          category: 'elektronik',
          store: 'N11',
          brand: 'Lenovo',
          createdAt: now,
        ),
        createMockDeal(
          id: 'b9',
          title: 'Casio Edifice Erkek Kol Saati',
          description: 'Çelik kordon su geçirmez paslanmaz saat',
          price: 3200.0,
          originalPrice: 4100.0,
          category: 'moda',
          store: 'Saat&Saat',
          brand: 'Casio',
          createdAt: now,
        ),
        createMockDeal(
          id: 'b10',
          title: 'Jacobs Monarch Filtre Kahve 500 gr',
          description: '%100 Arabica çekirdek öğütülmüş kahve',
          price: 185.0,
          originalPrice: 230.0,
          category: 'supermarket',
          store: 'Trendyol',
          brand: 'Jacobs',
          createdAt: now,
        ),

        // =======================================================
        // SEVİYE 2: 10 ORTA KARIŞIK İSİMLİ VE DETAYLI DUMMY ÜRÜN
        // =======================================================
        createMockDeal(
          id: 'm1',
          title: 'Samsung Galaxy S24 Ultra 512GB Titanyum Gri Akıllı Telefon',
          description: 'Snapdragon 8 Gen 3 12GB RAM 200MP Kameralı Amiral Gemisi',
          price: 64999.0,
          originalPrice: 73999.0,
          category: 'elektronik',
          store: 'Amazon',
          brand: 'Samsung',
          createdAt: now,
        ),
        createMockDeal(
          id: 'm2',
          title: 'Philips Hue Play HDMI Senkronizasyon Kutusu & Hue Lightbar İkili Paket',
          description: 'TV ve Monitör arkası renkli akıllı ortam aydınlatma kiti',
          price: 8499.0,
          originalPrice: 10200.0,
          category: 'ev_yasam',
          store: 'MediaMarkt',
          brand: 'Philips',
          createdAt: now,
        ),
        createMockDeal(
          id: 'm3',
          title: 'Bosch Serie 6 Çamaşır Makinesi 9kg 1400 Devir Gri WGG2440XTR',
          description: 'EcoSilence Drive leke çıkarma opsiyonlu sessiz çamaşır makinesi',
          price: 21900.0,
          originalPrice: 25500.0,
          category: 'ev_yasam',
          store: 'Vatan Bilgisayar',
          brand: 'Bosch',
          createdAt: now,
        ),
        createMockDeal(
          id: 'm4',
          title: "Nike Air Force 1 '07 Erkek Beyaz Spor Ayakkabı CW2288-111",
          description: 'Efsanevi deri sneaker günlük spor ayakkabı',
          price: 3699.0,
          originalPrice: 4299.0,
          category: 'moda',
          store: 'Nike',
          brand: 'Nike',
          createdAt: now,
        ),
        createMockDeal(
          id: 'm5',
          title: 'Sony WH-1000XM5 Kablosuz Gürültü Engelleyici Kulak Üstü Kulaklık Siyah',
          description: 'Gelişmiş ANC 30 saat pil ömrü HD mikrofonlu bluetooth kulaklık',
          price: 13299.0,
          originalPrice: 15499.0,
          category: 'elektronik',
          store: 'Hepsiburada',
          brand: 'Sony',
          createdAt: now,
        ),
        createMockDeal(
          id: 'm6',
          title: 'Delonghi Magnifica S Tam Otomatik Espresso ve Kahve Makinesi ECAM22.110.B',
          description: 'Süt köpürtücülü çekirdekten taze çekim kahve makinesi',
          price: 14750.0,
          originalPrice: 17900.0,
          category: 'ev_yasam',
          store: 'Amazon',
          brand: 'Delonghi',
          createdAt: now,
        ),
        createMockDeal(
          id: 'm7',
          title: 'Apple MacBook Air 13.6 inç M3 Çip 8GB RAM 256GB SSD Gece Yarısı',
          description: 'Ince hafif retina ekranlı yeni nesil macbook dizüstü',
          price: 38499.0,
          originalPrice: 42999.0,
          category: 'elektronik',
          store: 'PTTAVM',
          brand: 'Apple',
          createdAt: now,
        ),
        createMockDeal(
          id: 'm8',
          title: 'Cosori XXL 5.5 Litre Yağsız Sıcak Hava Fritözü Air Fryer CP158-AF',
          description: '11 ön ayarlı dokunmatik ekranlı az yağlı pişirici',
          price: 3499.0,
          originalPrice: 4499.0,
          category: 'ev_yasam',
          store: 'Trendyol',
          brand: 'Cosori',
          createdAt: now,
        ),
        createMockDeal(
          id: 'm9',
          title: 'Stanley Klasik Vakumlu Çelik Termos 1.4 Litre Yeşil',
          description: '40 saat sıcak/soğuk tutan ömür boyu garantili kamp termosu',
          price: 1890.0,
          originalPrice: 2350.0,
          category: 'spor_outdoor',
          store: 'Amazon',
          brand: 'Stanley',
          createdAt: now,
        ),
        createMockDeal(
          id: 'm10',
          title: 'Dyson V15 Detect Absolute Kablosuz Dikey Süpürge Sarı/Nikel',
          description: 'Lazer aydınlatmalı toz sensörlü şarjlı dikey süpürge',
          price: 27999.0,
          originalPrice: 31999.0,
          category: 'ev_yasam',
          store: 'Dyson',
          brand: 'Dyson',
          createdAt: now,
        ),

        // =========================================================================
        // SEVİYE 3: 10 ZOR / KARMAŞIK ÜRÜNLER, KUPON KODLARI VE MODEL NUMARALI ÜRÜN
        // =========================================================================
        createMockDeal(
          id: 'h1',
          title: 'Anker Eufy RoboVac X8 Hybrid Çift Türbinli Akıllı Robot Süpürge & Paspas T2261 - Siyah',
          description: '2x2000Pa güçlü emiş LiDAR navigasyon haritalamalı robot süpürge paspas',
          price: 11499.0,
          originalPrice: 14999.0,
          category: 'ev_yasam',
          store: 'Hepsiburada',
          brand: 'Anker',
          createdAt: now,
        ),
        createMockDeal(
          id: 'h2',
          title: "L'Oreal Paris Revitalift Laser X3 Yaşlanma Karşıtı Gece Bakım Kremi 50ml + Hediyeli Kutu",
          description: 'Pro-Xylane ve Hyaluronik asit içerikli kırışıklık karşıtı yüz kremi seti',
          price: 349.0,
          originalPrice: 499.0,
          category: 'kozmetik',
          store: 'Gratis',
          brand: "L'Oreal Paris",
          createdAt: now,
        ),
        createMockDeal(
          id: 'h3',
          title: 'Migros Sanal Market 1000 TL ve Üzeri Alışverişe 150 TL İndirim Kodu',
          description: 'Tüm sepet alışverişlerinde geçerli indirim kopyala: MIGROS150',
          price: 0.0,
          originalPrice: 150.0,
          couponCode: 'MIGROS150',
          category: 'supermarket',
          store: 'Migros',
          brand: 'Migros',
          createdAt: now,
        ),
        createMockDeal(
          id: 'h4',
          title: 'ASUS ROG Strix G16 G614JVR-N3095 Intel Core i7 14650HX 16GB 1TB SSD RTX4060 165Hz Oyun Bilgisayarı',
          description: '16 inç WUXGA oyuncu laptopu high performance gaming notebook',
          price: 52999.0,
          originalPrice: 59999.0,
          category: 'elektronik',
          store: 'Hepsiburada',
          brand: 'ASUS',
          createdAt: now,
        ),
        createMockDeal(
          id: 'h5',
          title: 'Yemeksepeti Restoran Siparişlerinde 80 TL İndirim Kuponu (Kupon: YEMEK80)',
          description: 'Seçili restoranlarda 200 TL üzeri ilk siparişe özel kupon kodu',
          price: 0.0,
          originalPrice: 80.0,
          couponCode: 'YEMEK80',
          category: 'dijital_hizmetler',
          store: 'Yemeksepeti',
          brand: 'Yemeksepeti',
          createdAt: now,
        ),
        createMockDeal(
          id: 'h6',
          title: 'LG OLED55C34LA 55 inç 139 Ekran 4K Smart OLED TV Alpha 9 AI İşlemci 120Hz Oyun Modu',
          description: 'Dolby Vision Atmos destekli premium OLED ekran televizyon',
          price: 49999.0,
          originalPrice: 58000.0,
          category: 'elektronik',
          store: 'Teknosa',
          brand: 'LG',
          createdAt: now,
        ),
        createMockDeal(
          id: 'h7',
          title: 'Gillette Labs Isıtmalı Tıraş Makinesi Başlangıç Seti & 2 Yedek Bıçak',
          description: 'Sıcak havlu etkili paslanmaz çelik bıçaklı erkek tıraş seti',
          price: 2490.0,
          originalPrice: 3200.0,
          category: 'kozmetik',
          store: 'Pazarama',
          brand: 'Gillette',
          createdAt: now,
        ),
        createMockDeal(
          id: 'h8',
          title: 'Trendyol Milla Siyah Yüksek Bel Dikişsiz Fitilli Tayt ST098-BLK',
          description: 'Esnek toparlayıcı sporda ve günlük kullanımda rahat kadın taytı',
          price: 199.0,
          originalPrice: 299.0,
          category: 'moda',
          store: 'Trendyol',
          brand: 'TrendyolMilla',
          createdAt: now,
        ),
        createMockDeal(
          id: 'h9',
          title: 'Xiaomi Smart Air Purifier 4 Pro Akıllı Hava Temizleyici HEPA Filtreli',
          description: 'Oda hava kalitesi sensörlü OLED ekranlı sessiz hava temizleme cihazı',
          price: 6799.0,
          originalPrice: 7999.0,
          category: 'ev_yasam',
          store: 'Mi Store',
          brand: 'Xiaomi',
          createdAt: now,
        ),
        createMockDeal(
          id: 'h10',
          title: 'GetirBüyük 300 TL Alışverişe 75 TL Anında İndirim Kodu (Kodu: GETIR75)',
          description: 'Market ürünlerinde geçerli hediye çek ve kampanya kodu',
          price: 0.0,
          originalPrice: 75.0,
          couponCode: 'GETIR75',
          category: 'supermarket',
          store: 'Getir',
          brand: 'Getir',
          createdAt: now,
        ),
      ];
    });

    test('30 Farklı Arama Senaryosunda %90+ Başarı Oranı Testi', () {
      final List<Map<String, dynamic>> testCases = [
        // --- SEVİYE 1: 10 BASİT ARAMA SENARYOSU ---
        {'query': 'seker', 'expectedId': 'b3', 'desc': 'Noktasız harfle fındıklı çikolata/şeker araması'},
        {'query': 'caykur turist cayi', 'expectedId': 'b1', 'desc': 'Noktasız harflerle Çaykur çayı'},
        {'query': 'IPHONE 15', 'expectedId': 'b2', 'desc': 'Büyük harfle iPhone 15 araması'},
        {'query': 'samsung tv', 'expectedId': 'b4', 'desc': 'Marka + Ürün türü araması'},
        {'query': 'sampuan', 'expectedId': 'b5', 'desc': 'Noktasız şampuan araması'},
        {'query': 'sutas sut', 'expectedId': 'b6', 'desc': 'Noktasız marka ve ürün araması'},
        {'query': 'puma ayakkabi', 'expectedId': 'b7', 'desc': 'Puma ayakkabı araması'},
        {'query': 'lenovo laptop', 'expectedId': 'b8', 'desc': 'Lenovo dizüstü araması'},
        {'query': 'casio saat', 'expectedId': 'b9', 'desc': 'Casio kol saati araması'},
        {'query': 'jacobs kahve', 'expectedId': 'b10', 'desc': 'Jacobs filtre kahve araması'},

        // --- SEVİYE 2: 10 ORTA KARIŞIK / DETAYLI ARAMA SENARYOSU ---
        {'query': 's24 ultra 512gb', 'expectedId': 'm1', 'desc': 'Model kodu ve hafıza ile telefon araması'},
        {'query': 'hue play hdmi', 'expectedId': 'm2', 'desc': 'Kısmi model adı ile aydınlatma kiti araması'},
        {'query': 'bosch wgg2440xtr', 'expectedId': 'm3', 'desc': 'Marka ve tam model kodu araması'},
        {'query': 'nike air force beyaz', 'expectedId': 'm4', 'desc': 'Sırasız kelimelerle ayakkabı araması'},
        {'query': 'wh-1000xm5 sony', 'expectedId': 'm5', 'desc': 'Model kodu + marka sırasız kulaklık araması'},
        {'query': 'delonghi ecam22', 'expectedId': 'm6', 'desc': 'Marka ve kısmi model kodu araması'},
        {'query': 'macbook air m3', 'expectedId': 'm7', 'desc': 'Model ve işlemci ismi araması'},
        {'query': 'cosori air fryer', 'expectedId': 'm8', 'desc': 'Marka ve ürün kategorisi araması'},
        {'query': 'stanley termos 1.4', 'expectedId': 'm9', 'desc': 'Marka, kategori ve hacim araması'},
        {'query': 'dyson v15', 'expectedId': 'm10', 'desc': 'Dyson süpürge model araması'},

        // --- SEVİYE 3: 10 ZOR KARMAŞIK & KUPON KODLU ARAMA SENARYOSU ---
        {'query': 'eufy t2261 robot paspas', 'expectedId': 'h1', 'desc': 'Zor: Marka, model, robot ve paspas sırasız arama'},
        {'query': 'revitalift gece kremi', 'expectedId': 'h2', 'desc': 'Zor: Fransızca marka adı ve krem araması'},
        {'query': 'MIGROS150', 'expectedId': 'h3', 'desc': 'Zor: Doğrudan kupon kodu ile arama'},
        {'query': 'g614jvr rtx4060 asus', 'expectedId': 'h4', 'desc': 'Zor: Karmaşık laptop kodları ve ekran kartı araması'},
        {'query': 'YEMEK80', 'expectedId': 'h5', 'desc': 'Zor: Yemeksepeti kupon kopyalama kodu araması'},
        {'query': 'oled55c34la lg', 'expectedId': 'h6', 'desc': 'Zor: TV tam model numarası araması'},
        {'query': 'gillette labs tiras', 'expectedId': 'h7', 'desc': 'Zor: Türkçe noktasız tıraş makinesi seti araması'},
        {'query': 'trendyolmilla st098', 'expectedId': 'h8', 'desc': 'Zor: Birleşik marka ve stok kodu araması'},
        {'query': 'xiaomi purifier 4 pro', 'expectedId': 'h9', 'desc': 'Zor: İngilizce model isimli hava temizleyici araması'},
        {'query': 'GETIR75', 'expectedId': 'h10', 'desc': 'Zor: Getir kupon kodu araması'},
      ];

      int passedCount = 0;
      final int totalCount = testCases.length;

      print('\n==========================================================');
      print('🚀 SMART SEARCH ENGINE - BENCHMARK TEST RAPORU');
      print('==========================================================\n');

      for (int i = 0; i < testCases.length; i++) {
        final tc = testCases[i];
        final String query = tc['query'];
        final String expectedId = tc['expectedId'];
        final String desc = tc['desc'];

        final results = DealSearchEngine.searchDeals(mockDeals, query);

        bool isSuccess = false;
        if (results.isNotEmpty) {
          // En tepedeki (en alakalı) sonuç beklenen fırsat mı?
          isSuccess = results.first.id == expectedId;
        }

        if (isSuccess) {
          passedCount++;
          final titleDisplay = results.first.title.length > 25 ? '${results.first.title.substring(0, 25)}...' : results.first.title;
          print('✅ [TEST ${(i + 1).toString().padLeft(2, '0')}/$totalCount PASS] Query: "$query" -> Bulunan: "$titleDisplay" ($desc)');
        } else {
          final String foundTitle = results.isNotEmpty ? results.first.title : 'HİÇBİR ŞEY BULUNAMADI';
          print('❌ [TEST ${(i + 1).toString().padLeft(2, '0')}/$totalCount FAIL] Query: "$query" -> Beklenen ID: $expectedId | Bulunan: "$foundTitle" ($desc)');
        }
      }

      final double successPercentage = (passedCount / totalCount) * 100;

      print('\n----------------------------------------------------------');
      print('📊 TEST SONUÇLARI ÖZETİ:');
      print(' Toplam Test Senaryosu : $totalCount');
      print(' Başarılı (Doğru Ürün) : $passedCount');
      print(' Hatalı / Bulunamayan  : ${totalCount - passedCount}');
      print(' 🎯 BAŞARI YÜZDESİ     : %${successPercentage.toStringAsFixed(1)}');
      print('==========================================================\n');

      // %90 BAŞARI ORANI HEDEFİ DOĞRULAMASI
      expect(successPercentage >= 90.0, isTrue,
          reason: 'Arama algoritması başarı oranı %90 altında kaldı! Mevcut: %$successPercentage');
    });
  });
}
