import '../models/category.dart';

class CategoryDetectionService {
  static final CategoryDetectionService _instance = CategoryDetectionService._internal();
  factory CategoryDetectionService() => _instance;
  CategoryDetectionService._internal();

  // Kategori ve alt kategori için keyword eşleştirmeleri
  static final Map<String, Map<String, List<String>>> _categoryKeywords = {
    'elektronik': {
      'Telefon & Aksesuarları': [
        'telefon', 'iphone', 'samsung', 'xiaomi', 'huawei', 'oppo', 'vivo', 'realme',
        'akıllı telefon', 'akilli telefon', 'cep telefonu', 'mobil telefon', 'telefon kılıfı', 'telefon kilifi', 'telefon camı', 'telefon cami',
        'powerbank', 'power bank', 'şarj aleti', 'sarj aleti', 'kablosuz şarj', 'kablosuz sarj', 'kulaklık', 'kulaklik', 'airpods', 'earbuds',
        'telefon aksesuar', 'telefon aksesuari', 'telefon kılıf', 'telefon kilif', 'ekran koruyucu',
        'phone', 'smartphone', 'mobile', 'charger', 'case', 'headphone', 'earphone'
      ],
      'Bilgisayar & Tablet': [
        'laptop', 'notebook', 'macbook', 'tablet', 'ipad', 'surface', 'chromebook',
        'bilgisayar', 'pc', 'masaüstü', 'all in one', 'monitör', 'klavye', 'mouse',
        'webcam', 'hoparlör', 'mikrofon', 'yazıcı', 'scanner', 'harddisk', 'ssd',
        'usb bellek', 'hafıza kartı', 'sd kart', 'micro sd'
      ],
      'TV & Ses Sistemleri': [
        'televizyon', 'tv', 'smart tv', 'led tv', 'oled', 'qled', 'soundbar',
        'hoparlör', 'bluetooth hoparlör', 'kablosuz hoparlör', 'ses sistemi',
        'home theater', 'projeksiyon', 'projector', 'anten', 'uydu alıcı'
      ],
      'Beyaz Eşya & Küçük Ev Aletleri': [
        'buzdolabı', 'çamaşır makinesi', 'bulaşık makinesi', 'fırın', 'ocak',
        'klima', 'aspiratör', 'elektrikli süpürge', 'robot süpürge', 'ütü',
        'kahve makinesi', 'su ısıtıcı', 'tost makinesi', 'mikser', 'blender',
        'dondurucu', 'derin dondurucu', 'mini buzdolabı'
      ],
      'Fotoğraf & Kamera': [
        'kamera', 'fotoğraf makinesi', 'dijital kamera', 'dslr', 'mirrorless',
        'action kamera', 'go pro', 'drone', 'quadcopter', 'lens', 'tripod',
        'kamera aksesuar', 'hafıza kartı', 'batarya', 'şarj cihazı'
      ],
    },
    'moda': {
      'Kadın Giyim': [
        'kadın', 'kadin', 'kadın giyim', 'kadin giyim', 'elbise', 'bluz', 'gömlek', 'gomlek', 'pantolon', 'jean',
        'etek', 'şort', 'sort', 'ceket', 'mont', 'kaban', 'trençkot', 'trenckot', 'sweatshirt',
        'hoodie', 'tişört', 'tisort', 'kazak', 'hırka', 'hirka', 'tayt', 'leggings', 'pijama',
        'iç çamaşırı', 'ic camasiri', 'sütyen', 'sutyen', 'çorap', 'corap', 'kadın ayakkabı', 'kadin ayakkabi', 'topuklu', 'babet',
        'sandalet', 'bot', 'çizme', 'cizme', 'kadın çanta', 'kadin canta', 'el çantası', 'el cantasi', 'sırt çantası', 'sirt cantasi',
        'dress', 'blouse', 'shirt', 'pants', 'jeans', 'skirt', 'jacket', 'coat', 'sweater'
      ],
      'Erkek Giyim': [
        'erkek', 'erkek giyim', 'gömlek', 'gomlek', 'pantolon', 'jean', 'kısa pantolon', 'kisa pantolon',
        'şort', 'sort', 'tişört', 'tisort', 'polo', 'kazak', 'sweatshirt', 'hoodie', 'ceket',
        'mont', 'kaban', 'trençkot', 'trenckot', 'takım elbise', 'takim elbise', 'yelek', 'iç çamaşırı', 'ic camasiri',
        'boxer', 'çorap', 'corap', 'erkek ayakkabı', 'erkek ayakkabi', 'spor ayakkabı', 'spor ayakkabi', 'klasik ayakkabı', 'klasik ayakkabi',
        'bot', 'terlik', 'sandalet',
        'shirt', 'pants', 'jeans', 't-shirt', 'tshirt', 'polo', 'sweater', 'jacket', 'coat', 'suit'
      ],
      'Ayakkabı & Çanta': [
        'ayakkabı', 'ayakkabi', 'spor ayakkabı', 'spor ayakkabi', 'krampon', 'bot', 'çizme', 'cizme',
        'terlik', 'sandalet', 'topuklu', 'babet', 'balerin', 'sneaker', 'spor ayakkabi',
        'çanta', 'canta', 'el çantası', 'el cantasi', 'sırt çantası', 'sirt cantasi',
        'laptop çantası', 'laptop cantasi', 'valiz', 'bavul', 'cüzdan', 'cuzdan', 'kemer',
        'saat', 'kol saati', 'güneş gözlüğü', 'gunes gozlugu', 'şapka', 'sapka', 'bere', 'eldiven',
        'bag', 'backpack', 'shoe', 'shoes', 'sandal', 'boot', 'boots'
      ],
      'Saat & Aksesuar': [
        'saat', 'kol saati', 'akıllı saat', 'smartwatch', 'apple watch',
        'aksesuar', 'kemer', 'cüzdan', 'güneş gözlüğü', 'şapka', 'bere',
        'eldiven', 'atkı', 'kolye', 'küpe', 'yüzük', 'bilezik', 'bileklik'
      ],
      'Çocuk Giyim': [
        'çocuk', 'bebek', 'çocuk giyim', 'bebek giyim', 'çocuk ayakkabı',
        'bebek ayakkabı', 'okul kıyafeti', 'çocuk çanta', 'bebek bezi',
        'çocuk oyuncak', 'bebek oyuncak'
      ],
    },
    'ev_yasam': {
      'Mobilya': [
        'mobilya', 'kanepe', 'koltuk', 'masa', 'sandalye', 'yatak', 'dolap',
        'gardırop', 'komodin', 'sehpa', 'tv ünitesi', 'kitaplık', 'raflı dolap',
        'mutfak dolabı', 'banyo dolabı', 'çalışma masası', 'ofis koltuğu'
      ],
      'Ev Tekstili': [
        'çarşaf', 'yorgan', 'battaniye', 'yastık', 'nevresim', 'perde',
        'halı', 'kilim', 'paspas', 'havlu', 'bornoz', 'terlik', 'ev terliği'
      ],
      'Mutfak Gereçleri': [
        'tava', 'tencere', 'tava seti', 'tencere seti', 'bıçak', 'bıçak seti',
        'kesme tahtası', 'saklama kabı', 'cam kavanoz', 'termos', 'su şişesi',
        'fincan', 'bardak', 'tabak', 'çatal', 'kaşık', 'bıçak', 'servis takımı'
      ],
      'Aydınlatma & Dekorasyon': [
        'lamba', 'avize', 'aydınlatma', 'led', 'ampul', 'dekorasyon',
        'duvar saati', 'resim', 'tablo', 'vazo', 'mum', 'mumluk', 'ayna',
        'panjur', 'stor', 'jaluzi'
      ],
      'Kırtasiye & Ofis Malzemeleri': [
        'kalem', 'defter', 'ajanda', 'planner', 'dosya', 'klasör', 'zarf',
        'kağıt', 'a4', 'yazıcı kağıdı', 'mürekkepli kalem', 'tükenmez kalem',
        'kurşun kalem', 'silgi', 'kalemtraş', 'makas', 'yapıştırıcı', 'bant',
        'zımba', 'delgeç', 'not defteri', 'post it', 'etiket'
      ],
    },
    'anne_bebek': {
      'Bebek Bezi & Islak Mendil': [
        'bebek bezi', 'bez', 'ıslak mendil', 'bebek mendili', 'alt açma',
        'bebek bakım', 'pişik kremi', 'bebek losyonu'
      ],
      'Bebek Arabası & Oto Koltuğu': [
        'bebek arabası', 'puset', 'oyuncak arabası', 'oto koltuğu', 'bebek koltuğu',
        'araç koltuğu', 'bebek taşıyıcı', 'kanguru', 'sling'
      ],
      'Beslenme & Emzirme': [
        'biberon', 'emzik', 'mama kabı', 'mama kaşığı', 'suluk', 'bebek çatalı',
        'emzirme yastığı', 'göğüs pompası', 'süt saklama', 'mama ısıtıcı'
      ],
      'Bebek Odası & Güvenlik': [
        'bebek yatağı', 'beşik', 'bebek karyolası', 'bebek odası', 'bebek mobilya',
        'bebek güvenlik', 'bebek kapısı', 'priz koruyucu', 'köşe koruyucu'
      ],
      'Bebek Oyuncakları': [
        'bebek oyuncak', 'oyuncak', 'eğitici oyuncak', 'bebek oyuncağı',
        'peluş oyuncak', 'bebek bebek', 'oyuncak araba', 'lego', 'puzzle'
      ],
    },
    'kozmetik': {
      'Parfüm & Deodorant': [
        'parfüm', 'kolonya', 'deodorant', 'roll on', 'sprey', 'parfüm seti',
        'kadın parfüm', 'erkek parfüm', 'unisex parfüm', 'body spray'
      ],
      'Makyaj Ürünleri': [
        'ruj', 'fondöten', 'kapatıcı', 'pudra', 'allık', 'fırça', 'makyaj fırçası',
        'göz kalemi', 'maskara', 'far', 'palet', 'highlighter', 'kontür',
        'dudak parlatıcı', 'lipstick', 'lip gloss', 'eyeshadow', 'eyeliner'
      ],
      'Cilt & Yüz Bakımı': [
        'nemlendirici', 'krem', 'yüz kremi', 'güneş kremi', 'spf', 'serum',
        'tonik', 'temizleme', 'yüz temizleme', 'peeling', 'maske', 'yüz maskesi',
        'göz kremi', 'anti aging', 'yaşlanma karşıtı', 'cilt bakım'
      ],
      'Saç Bakımı': [
        'şampuan', 'saç kremi', 'bakım kremi', 'saç maskesi', 'saç spreyi',
        'jöle', 'wax', 'saç fırçası', 'tarak', 'saç kurutma', 'fön makinesi',
        'düzleştirici', 'maşa', 'saç boyası', 'renk açıcı'
      ],
      'Ağız & Diş Bakımı': [
        'diş fırçası', 'elektrikli diş fırçası', 'diş macunu', 'ağız bakım suyu',
        'gargara', 'diş ipi', 'diş beyazlatıcı', 'ağız spreyi'
      ],
    },
    'spor_outdoor': {
      'Spor Giyim & Ayakkabı': [
        'spor ayakkabı', 'koşu ayakkabı', 'fitness', 'egzersiz', 'spor kıyafet',
        'eşofman', 'şort', 'tişört', 'spor çorap', 'spor çanta', 'mat',
        'yoga matı', 'pilates matı', 'dambıl', 'halter', 'ağırlık'
      ],
      'Fitness & Kondisyon': [
        'fitness', 'koşu bandı', 'bisiklet', 'eliptik', 'dambıl', 'halter',
        'ağırlık seti', 'fitness ekipman', 'koşu bandı', 'ev spor aleti'
      ],
      'Kamp & Doğa Malzemeleri': [
        'çadır', 'uyku tulumu', 'mat', 'kamp', 'kamp malzemesi', 'kamp çantası',
        'kamp sandalyesi', 'kamp masası', 'fener', 'kafa lambası', 'termos',
        'kamp ocağı', 'tüp', 'doğa yürüyüşü', 'trekking'
      ],
      'Bisiklet & Ekipmanları': [
        'bisiklet', 'mountain bike', 'şehir bisikleti', 'elektrikli bisiklet',
        'bisiklet kaskı', 'bisiklet aksesuar', 'bisiklet pompası', 'bisiklet kilidi'
      ],
    },
    'supermarket': {
      'Gıda Ürünleri': [
        'gıda', 'yiyecek', 'içecek', 'atıştırmalık', 'çikolata', 'bisküvi',
        'cips', 'kraker', 'konserve', 'makarna', 'pirinç', 'bulgur', 'bakliyat',
        'zeytinyağı', 'ayçiçek yağı', 'salça', 'baharat', 'çay', 'kahve',
        'süt', 'yoğurt', 'peynir', 'yumurta', 'et', 'tavuk', 'balık'
      ],
      'Deterjan & Temizlik': [
        'deterjan', 'çamaşır deterjanı', 'bulaşık deterjanı', 'yumuşatıcı',
        'temizlik', 'cam temizleyici', 'yüzey temizleyici', 'banyo temizleyici',
        'tuvalet temizleyici', 'sıvı sabun', 'el sabunu', 'bulaşık süngeri',
        'temizlik bezi', 'mop', 'paspas'
      ],
      'Kağıt Ürünleri': [
        'tuvalet kağıdı', 'peçete', 'kağıt havlu', 'mendil', 'hijyenik ped',
        'bebek bezi', 'ıslak mendil', 'alüminyum folyo', 'streç film',
        'buzdolabı poşeti', 'çöp poşeti'
      ],
      'Kedi & Köpek Ürünleri': [
        'kedi maması', 'köpek maması', 'kuru mama', 'yaş mama', 'konserve',
        'kedi kumu', 'kum kabı', 'oyuncak', 'tasma', 'kemer', 'köpek tasması',
        'kedi tırmalama', 'köpek yatağı', 'kedi yatağı'
      ],
    },
    'yapi_oto': {
      'Elektrikli Aletler & Hırdavat': [
        'matkap', 'vidalama', 'tornavida', 'anahtar', 'pense', 'çekiç',
        'keski', 'testere', 'elektrikli alet', 'akülü matkap', 'şarjlı matkap',
        'hırdavat', 'vida', 'çivi', 'dübel', 'zımba', 'zımba teli'
      ],
      'Oto Aksesuar & Bakım': [
        'oto', 'araba', 'araç', 'oto aksesuar', 'araç aksesuar', 'koltuk kılıfı',
        'paspas', 'araç paspası', 'araç temizlik', 'cam suyu', 'motor yağı',
        'fren balata', 'lastik', 'jant', 'araç bakım', 'oto bakım'
      ],
      'Banyo & Tesisat': [
        'banyo', 'lavabo', 'klozet', 'duşakabin', 'küvet', 'musluk', 'batarya',
        'duş başlığı', 'banyo aksesuar', 'banyo dolabı', 'ayna', 'banyo aynası',
        'havlu askısı', 'sabunluk', 'diş fırçası kabı'
      ],
      'Bahçe Malzemeleri': [
        'bahçe', 'çim biçme', 'çim biçme makinesi', 'tırpan', 'budama makası',
        'bahçe hortumu', 'sulama', 'sulama sistemi', 'gübre', 'toprak',
        'saksı', 'bitki', 'tohum', 'fide', 'bahçe aleti'
      ],
    },
    'kitap_hobi': {
      'Kitap & Dergi': [
        'kitap', 'roman', 'hikaye', 'ders kitabı', 'test kitabı', 'yaprak test',
        'ders notu', 'ders anlatım', 'edebiyat', 'tarih', 'felsefe', 'bilim',
        'dergi', 'magazin', 'gazete', 'manga', 'çizgi roman', 'comic'
      ],
      'Müzik Enstrümanları': [
        'gitar', 'piyano', 'keman', 'bağlama', 'saz', 'davul', 'bateri',
        'flüt', 'klarnet', 'saksafon', 'trompet', 'müzik aleti', 'enstrüman',
        'gitar teli', 'akort aleti', 'metronom', 'mikrofon', 'hoparlör'
      ],
      'Oyun Konsolları & Video Oyunları': [
        'playstation', 'xbox', 'nintendo', 'switch', 'oyun konsolu', 'konsol',
        'oyun', 'video oyun', 'oyun kumandası', 'joystick', 'oyun koltuğu',
        'gaming', 'oyun bilgisayarı', 'gaming laptop', 'gaming mouse', 'gaming klavye'
      ],
      'Hobi & Sanat Malzemeleri': [
        'hobi', 'sanat', 'resim', 'boya', 'fırça', 'tuval', 'palet', 'kalem',
        'kurşun kalem', 'pastel', 'suluboya', 'akrilik', 'yağlı boya', 'guaj',
        'maket', 'model', 'puzzle', 'yapboz', 'lego', 'oyuncak', 'el işi',
        'dikiş', 'nakış', 'örgü', 'tığ', 'şiş', 'iplik', 'kumaş'
      ],
    },
  };

  /// Metinden kategori ve alt kategori tespit eder
  /// 
  /// [text] Tespit edilecek metin (başlık, açıklama vb.)
  /// 
  /// Returns: Map with 'categoryId' and 'subCategory' keys, or null if no match
  static Map<String, String?>? detectCategory(String text) {
    if (text.isEmpty) return null;

    // Metni küçük harfe çevir ve Türkçe karakterleri normalize et
    final normalizedText = _normalizeText(text.toLowerCase());
    final originalText = text.toLowerCase();

    print('🔍 Kategori tespiti başlatılıyor: "$text"');
    print('📝 Normalize edilmiş metin: "$normalizedText"');

    // Her kategori için skor hesapla
    final categoryScores = <String, Map<String, double>>{};

    for (final categoryEntry in _categoryKeywords.entries) {
      final categoryId = categoryEntry.key;
      final subCategories = categoryEntry.value;
      categoryScores[categoryId] = {};

      for (final subCategoryEntry in subCategories.entries) {
        final subCategory = subCategoryEntry.key;
        final keywords = subCategoryEntry.value;

        // Her keyword için eşleşme kontrolü
        double score = 0;
        for (final keyword in keywords) {
          final normalizedKeyword = _normalizeText(keyword.toLowerCase());
          final originalKeyword = keyword.toLowerCase();
          
          // Tam eşleşme (en yüksek skor) - hem normalize hem orijinal metinde
          if (normalizedText.contains(normalizedKeyword) || originalText.contains(originalKeyword)) {
            score += 3.0;
            print('   ✅ Tam eşleşme: "$keyword" (+3.0)');
          }
          
          // Kelime bazlı eşleşme (orta skor)
          final words = normalizedText.split(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+'));
          for (final word in words) {
            if (word.length >= 3) {
              // Kelime keyword içinde geçiyor mu?
              if (normalizedKeyword.contains(word)) {
                score += 1.0;
              }
              // Keyword kelime içinde geçiyor mu?
              if (word.contains(normalizedKeyword)) {
                score += 1.0;
              }
              // Tam kelime eşleşmesi (daha yüksek skor)
              if (word == normalizedKeyword) {
                score += 2.0;
              }
            }
          }
        }

        if (score > 0) {
          categoryScores[categoryId]![subCategory] = score;
          print('   📊 $categoryId > $subCategory: $score puan');
        }
      }
    }

    // En yüksek skorlu kategori ve alt kategoriyi bul
    String? bestCategoryId;
    String? bestSubCategory;
    double bestScore = 0;

    for (final categoryEntry in categoryScores.entries) {
      for (final subCategoryEntry in categoryEntry.value.entries) {
        if (subCategoryEntry.value > bestScore) {
          bestScore = subCategoryEntry.value;
          bestCategoryId = categoryEntry.key;
          bestSubCategory = subCategoryEntry.key;
        }
      }
    }

    // Minimum skor eşiği (çok düşük skorları kabul etme)
    if (bestScore < 1.5) {
      print('❌ Skor çok düşük: $bestScore (minimum: 1.5)');
      return null;
    }

    print('✅ En iyi eşleşme: $bestCategoryId > $bestSubCategory (skor: $bestScore)');

    return {
      'categoryId': bestCategoryId,
      'subCategory': bestSubCategory,
    };
  }

  /// Türkçe karakterleri normalize eder
  static String _normalizeText(String text) {
    return text
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
  }
}

