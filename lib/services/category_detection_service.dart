import '../utils/test_logger.dart';
import 'category_keywords.dart';

void _log(String message) {
  LinkPreviewLogger.log("[Category] $message");
}

class CategoryDetectionService {
  static final CategoryDetectionService _instance = CategoryDetectionService._internal();
  factory CategoryDetectionService() => _instance;
  CategoryDetectionService._internal();

  static final Map<String, Map<String, List<String>>> _categoryKeywords = categoryKeywords;
  static final List<String> _strongKeywords = strongKeywords;
  static final List<String> _weakKeywords = weakKeywords;

  static double _getKeywordWeight(String keyword) {
    if (_strongKeywords.contains(keyword)) return 10.0;
    if (_weakKeywords.contains(keyword)) return 2.0;
    return 5.0; // Varsayılan ağırlık
  }

  /// Metinden kategori ve alt kategori tespit eder
  /// 
  /// [text] Tespit edilecek metin (başlık, açıklama vb.)
  /// [url] Ürün bağlantısı (isteğe bağlı)
  /// [store] Mağaza adı (isteğe bağlı)
  /// 
  /// Returns: Map with 'categoryId' and 'subCategory' keys, or null if no match
  static Map<String, String?>? detectCategory(String text, {String? url, String? store}) {
    final lowerUrl = (url ?? '').toLowerCase();
    final lowerStore = (store ?? '').toLowerCase();
    final lowerText = text.toLowerCase();

    final isGetirOrMigros = lowerUrl.contains('getir.com') ||
        lowerUrl.contains('migros.com.tr') ||
        lowerStore.contains('getir') ||
        lowerStore.contains('migros') ||
        lowerText.contains('getir.com') ||
        lowerText.contains('migros.com.tr');

    final result = _detectCategoryInternal(text);

    if (isGetirOrMigros) {
      String? subCategory;
      if (result != null && result['categoryId'] == 'supermarket') {
        subCategory = result['subCategory'];
      }
      subCategory ??= _findSupermarketSubCategory(lowerText);
      subCategory ??= 'Gıda Ürünleri';

      _log('🛒 Getir/Migros ürünü tespit edildi -> Kategori: supermarket, Alt Kategori: $subCategory');

      return {
        'categoryId': 'supermarket',
        'subCategory': subCategory,
      };
    }

    return result;
  }

  static String? _findSupermarketSubCategory(String lowerText) {
    final supermarketCategories = _categoryKeywords['supermarket'];
    if (supermarketCategories == null) return null;

    final normalizedText = _normalizeText(lowerText);

    double bestScore = 0;
    String? bestSubCategory;

    for (final entry in supermarketCategories.entries) {
      final subCategory = entry.key;
      final keywords = entry.value;

      double score = 0;
      for (final keyword in keywords) {
        final normalizedKeyword = _normalizeText(keyword.toLowerCase());
        if (normalizedText.contains(normalizedKeyword)) {
          final weight = _getKeywordWeight(normalizedKeyword);
          score += weight;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestSubCategory = subCategory;
      }
    }

    return bestScore > 0 ? bestSubCategory : null;
  }

  static Map<String, String?>? _detectCategoryInternal(String text) {
    if (text.isEmpty) return null;

    // Metni küçük harfe çevir ve Türkçe karakterleri normalize et
    final normalizedText = _normalizeText(text.toLowerCase());
    final originalText = text.toLowerCase();
    
    // Metni kelimelere ayır (Performans için tek bir kez ayırıyoruz)
    final words = normalizedText.split(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+'));
    final originalWords = originalText.split(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+'));

    _log('🔍 Kategori tespiti başlatılıyor: "$text"');
    _log('📝 Normalize edilmiş metin: "$normalizedText"');

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
          
          // 1. Öbek/Phrase (N-Gram) Eşleşmesi: Kelime boşluk içeriyorsa bütünsel kontrol et (Çok güçlü sinyal, +12.0)
          if (normalizedKeyword.contains(' ')) {
            bool matchesPhrase = normalizedText.contains(normalizedKeyword) || originalText.contains(originalKeyword);
            
            // Sonek kaynaklı (plural/possessive) farkları yakalamak için gövde karşılaştırması
            if (!matchesPhrase) {
              final keywordWords = normalizedKeyword.split(' ');
              for (int i = 0; i <= words.length - keywordWords.length; i++) {
                bool sequenceMatches = true;
                for (int j = 0; j < keywordWords.length; j++) {
                  final textWord = words[i + j];
                  final keyWord = keywordWords[j];
                  if (_stem(textWord) != _stem(keyWord)) {
                    sequenceMatches = false;
                    break;
                  }
                }
                if (sequenceMatches) {
                  matchesPhrase = true;
                  break;
                }
              }
            }

            if (matchesPhrase) {
              score += 12.0;
              _log('   🔥 Tam öbek (N-Gram) eşleşmesi: "$keyword" (+12.0)');
              continue; // Diğer kelime bazlı eşleşmelere bakmaya gerek yok
            }
          }

          final double weight = _getKeywordWeight(normalizedKeyword);

          // 2. Tam kelime eşleşmesi
          bool exactWordMatch = false;
          for (int i = 0; i < words.length; i++) {
            final word = words[i];
            final originalWord = originalWords.length > i ? originalWords[i] : '';
            
            if (word == normalizedKeyword || 
                originalWord == originalKeyword ||
                _stem(word) == _stem(normalizedKeyword)) {
              score += weight;
              exactWordMatch = true;
              _log('   ✅ Tam kelime eşleşmesi: "$keyword" (+$weight)');
              break;
            }
          }
          
          // 3. Alt metin eşleşmesi (tam kelime eşleşmediyse)
          if (!exactWordMatch) {
            bool isSubMatch = false;
            for (final word in words) {
              if (word.startsWith(normalizedKeyword)) {
                if (normalizedKeyword.length >= 4 || (word.length - normalizedKeyword.length) <= 3) {
                  isSubMatch = true;
                  break;
                }
              }
            }
            if (isSubMatch) {
              final double partialWeight = weight * 0.6; // Kelime ağırlığının %60'ı kadar
              score += partialWeight;
              _log('   ✅ Alt metin eşleşmesi: "$keyword" (+$partialWeight)');
            }
          }
          
          // 4. Kelime benzerlik eşleşmesi (sadece zayıf sinyaller için bakma ve boşluk içermeyen anahtar kelimeler)
          if (!exactWordMatch && weight > 2.0 && !normalizedKeyword.contains(' ')) {
            for (final word in words) {
              if (word.length >= 3) {
                if (normalizedKeyword.contains(word) || word.contains(normalizedKeyword)) {
                  score += 1.0;
                }
              }
            }
          }
        }

        if (score > 0) {
          categoryScores[categoryId]![subCategory] = score;
          _log('   📊 $categoryId > $subCategory: $score puan');
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

    // Minimum skor eşiği
    final minScore = normalizedText.split(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+')).length == 1 ? 1.5 : 2.0;
    if (bestScore < minScore) {
      _log('❌ Skor çok düşük: $bestScore (minimum: $minScore)');
      return null;
    }

    // 5. Negatif İstisnalar (Exclusions) Post-Processing
    final refinedResult = _applyNegativeExclusions(normalizedText, bestCategoryId, bestSubCategory);
    bestCategoryId = refinedResult['categoryId'];
    bestSubCategory = refinedResult['subCategory'];

    _log('✅ Nihai Eşleşme (İstisnalar Sonrası): $bestCategoryId > $bestSubCategory (skor: $bestScore)');

    return {
      'categoryId': bestCategoryId,
      'subCategory': bestSubCategory,
    };
  }

  /// Negatif kurallar ve çapraz eşleşmeleri düzelten istisna yöneticisi
  static Map<String, String?> _applyNegativeExclusions(String normalizedText, String? categoryId, String? subCategory) {
    String? finalCategoryId = categoryId;
    String? finalSubCategory = subCategory;

    final words = normalizedText.split(RegExp(r'[^\w]+'));
    final isExplicitInvestmentGold = 
        normalizedText.contains('kulce') ||
        normalizedText.contains('külçe') ||
        normalizedText.contains('yatirimlik altin') ||
        normalizedText.contains('yatırımlık altın') ||
        normalizedText.contains('yatirimlik gumus') ||
        normalizedText.contains('yatırımlık gümüş') ||
        normalizedText.contains('sarrafiye') ||
        normalizedText.contains('ziynet') ||
        normalizedText.contains('gram altin') ||
        normalizedText.contains('gram altın') ||
        normalizedText.contains('gr altin') ||
        normalizedText.contains('gr altın') ||
        normalizedText.contains('ceyrek altin') ||
        normalizedText.contains('çeyrek altın') ||
        normalizedText.contains('yarim altin') ||
        normalizedText.contains('yarım altın') ||
        normalizedText.contains('tam altin') ||
        normalizedText.contains('tam altın') ||
        normalizedText.contains('cumhuriyet altin') ||
        normalizedText.contains('cumhuriyet altın') ||
        normalizedText.contains('ata altin') ||
        normalizedText.contains('ata altın') ||
        normalizedText.contains('ata lira') ||
        normalizedText.contains('has altin') ||
        normalizedText.contains('has altın') ||
        normalizedText.contains('resat altin') ||
        normalizedText.contains('reşat altın') ||
        normalizedText.contains('hamit altin') ||
        normalizedText.contains('hamit altın') ||
        normalizedText.contains('gremse') ||
        normalizedText.contains('24 ayar') ||
        (normalizedText.contains('22 ayar') && !normalizedText.contains('bilezik') && !normalizedText.contains('kolye') && !normalizedText.contains('kupe') && !normalizedText.contains('yuzuk')) ||
        (normalizedText.contains('altin') && (normalizedText.contains('nadir gold') || normalizedText.contains('iar') || normalizedText.contains('ahlatci') || normalizedText.contains('ahlatçı') || normalizedText.contains('harem altin') || normalizedText.contains('harem altın') || normalizedText.contains('aga gold') || normalizedText.contains('darphane') || normalizedText.contains('vekgold'))) ||
        RegExp(r'\b\d+\s*(gram|gr|kg|kilo)\s*.*(altin|altın|gumus|gümüş|gold|silver|kulce|külçe)\b').hasMatch(normalizedText) ||
        RegExp(r'\b(altin|altın|gumus|gümüş|gold|silver|kulce|külçe)\s*.*(\d+\s*(gram|gr|kg|kilo))\b').hasMatch(normalizedText);

    final isFinishedJewelry = 
        normalizedText.contains('kolye') ||
        normalizedText.contains('kupe') ||
        normalizedText.contains('küpe') ||
        normalizedText.contains('yuzuk') ||
        normalizedText.contains('yüzük') ||
        normalizedText.contains('alyans') ||
        normalizedText.contains('tektas') ||
        normalizedText.contains('tektaş') ||
        normalizedText.contains('bestas') ||
        normalizedText.contains('beştaş') ||
        normalizedText.contains('pirlanta') ||
        normalizedText.contains('pırlanta') ||
        normalizedText.contains('halhal') ||
        normalizedText.contains('sahmeran') ||
        normalizedText.contains('şahmeran') ||
        normalizedText.contains('bros') ||
        normalizedText.contains('broş') ||
        normalizedText.contains('toka') ||
        (normalizedText.contains('bileklik') && !isExplicitInvestmentGold) ||
        (normalizedText.contains('zincir') && !isExplicitInvestmentGold && !normalizedText.contains('kulce') && !normalizedText.contains('külçe'));

    // 0. Termos Yönlendirmesi (Sağlık/gıda veya takı yerine Mutfak Gereçleri veya Kamp Malzemelerine gitmeli)
    if (normalizedText.contains('termos') || normalizedText.contains('thermos')) {
      final isOutdoor = normalizedText.contains('kamp') || 
                        normalizedText.contains('outdoor') || 
                        normalizedText.contains('doga') || 
                        normalizedText.contains('doğa') || 
                        normalizedText.contains('stanley') ||
                        normalizedText.contains('dag') || 
                        normalizedText.contains('dağ') ||
                        normalizedText.contains('trekking') ||
                        normalizedText.contains('hiking') ||
                        categoryId == 'spor_outdoor';
      if (isOutdoor) {
        finalCategoryId = 'spor_outdoor';
        finalSubCategory = 'Kamp & Doğa Malzemeleri';
      } else {
        finalCategoryId = 'ev_yasam';
        finalSubCategory = 'Mutfak Gereçleri';
      }
    }

    // 1. Yastık/Yorgan Kılıfı (Ev Tekstili olmalı, Telefon Kılıfı / Elektronik değil)
    if (normalizedText.contains('kilif')) {
      final isBedding = normalizedText.contains('yastik') ||
                        normalizedText.contains('yorgan') ||
                        normalizedText.contains('yatak') ||
                        normalizedText.contains('kirlent') ||
                        normalizedText.contains('nevresim');
      if (isBedding) {
        finalCategoryId = 'ev_yasam';
        finalSubCategory = 'Ev Tekstili';
      }
    }

    // 2. Bebek Deterjanı, Yumuşatıcı, Sabun (Süpermarket olmalı, Anne Bebek değil)
    if (normalizedText.contains('bebek') || normalizedText.contains('baby')) {
      final isDetergent = normalizedText.contains('deterjan') ||
                          normalizedText.contains('yumusatici') ||
                          normalizedText.contains('sabun') ||
                          normalizedText.contains('temizleyici');
      if (isDetergent) {
        finalCategoryId = 'supermarket';
        finalSubCategory = 'Deterjan & Temizlik';
      }
    }

    // 3. Bebek Şampuanı, Bebek Yağı, Bebek Kremi (Kozmetik olmalı, Anne Bebek değil)
    if (normalizedText.contains('bebek') || normalizedText.contains('baby')) {
      final isCosmetic = normalizedText.contains('sampuan') ||
                         normalizedText.contains('yag') ||
                         normalizedText.contains('krem') ||
                         normalizedText.contains('losyon') ||
                         normalizedText.contains('macun');
      if (isCosmetic) {
        finalCategoryId = 'kozmetik';
        finalSubCategory = normalizedText.contains('sampuan') ? 'Saç Bakımı' : 'Cilt & Yüz Bakımı';
      }
    }

    // 4. Spor Kıyafet / Spor Ayakkabı - sadece genel moda bağlamında moda'ya git
    // Spor markası veya 'spor giyim' bağlamı varsa spor_outdoor olarak bırak
    if (normalizedText.contains('spor') && finalCategoryId == 'spor_outdoor') {
      final isSportsContext = normalizedText.contains('spor giyim') ||
                              normalizedText.contains('under armour') ||
                              normalizedText.contains('nike') ||
                              normalizedText.contains('adidas') ||
                              normalizedText.contains('puma') ||
                              normalizedText.contains('reebok') ||
                              normalizedText.contains('decathlon') ||
                              normalizedText.contains('columbia') ||
                              normalizedText.contains('erkek spor') ||
                              normalizedText.contains('kadin spor') ||
                              normalizedText.contains('spor tisort') ||
                              normalizedText.contains('spor sort');
      // spor_outdoor'da kalıyorsa dokunma
      if (!isSportsContext) {
        final isClothingOrShoe = normalizedText.contains('ayakkabi') ||
                                normalizedText.contains('tisort') ||
                                normalizedText.contains('t-shirt') ||
                                normalizedText.contains('tshirt') ||
                                normalizedText.contains('sort') ||
                                normalizedText.contains('tayt') ||
                                normalizedText.contains('mont') ||
                                normalizedText.contains('esofman') ||
                                normalizedText.contains('yelek') ||
                                normalizedText.contains('corap') ||
                                normalizedText.contains('canta') ||
                                normalizedText.contains('ceket');
        if (isClothingOrShoe) {
          finalCategoryId = 'moda';
          finalSubCategory = normalizedText.contains('ayakkabi') ? 'Ayakkabı & Çanta' : 'Kadın Giyim';
        }
      }
    }

    // 5. Akıllı Saat / Smartwatch (Elektronik olmalı, Moda'nın klasik Kol Saatleri değil)
    if (normalizedText.contains('akilli saat') ||
        normalizedText.contains('smartwatch') ||
        normalizedText.contains('akilli bileklik') ||
        normalizedText.contains('watch gt') ||
        normalizedText.contains('galaxy watch') ||
        normalizedText.contains('apple watch') ||
        normalizedText.contains('garmin') ||
        (normalizedText.contains('watch') && normalizedText.contains('huawei')) ||
        (normalizedText.contains('watch') && normalizedText.contains('samsung')) ||
        (normalizedText.contains('watch') && normalizedText.contains('apple'))) {
      finalCategoryId = 'elektronik';
      finalSubCategory = 'Telefon & Aksesuarları';
    }

    // 6. Bebek kelimesi geçip giyim kelimeleri geçmiyorsa Çocuk Giyim yerine Anne Bebek olmalı
    if (finalCategoryId == 'moda' && finalSubCategory == 'Çocuk Giyim') {
      final hasBaby = normalizedText.contains('bebek') || normalizedText.contains('baby');
      if (hasBaby) {
        final hasClothing = normalizedText.contains('giyim') ||
                            normalizedText.contains('tulum') ||
                            normalizedText.contains('elbise') ||
                            normalizedText.contains('pantolon') ||
                            normalizedText.contains('tisort') ||
                            normalizedText.contains('t-shirt') ||
                            normalizedText.contains('tshirt') ||
                            normalizedText.contains('corap') ||
                            normalizedText.contains('ayakkabi') ||
                            normalizedText.contains('patik') ||
                            normalizedText.contains('mont') ||
                            normalizedText.contains('yelek') ||
                            normalizedText.contains('ceket') ||
                            normalizedText.contains('bere') ||
                            normalizedText.contains('sapka') ||
                            normalizedText.contains('takim');
        if (!hasClothing) {
          finalCategoryId = 'anne_bebek';
          finalSubCategory = 'Bebek Odası & Güvenlik';
        }
      }
    }

    // 7. Yatırım Altın vs. Takı/Mücevher Ayrımı

    if (isExplicitInvestmentGold && !isFinishedJewelry) {
      finalCategoryId = 'finans_kampanyalar';
      finalSubCategory = 'Yatırım & Değerli Metaller';
    } else if (isFinishedJewelry || words.contains('taki') || words.contains('takilar') || words.contains('mucevher')) {
      final isSmartWearable = normalizedText.contains('akilli saat') ||
                              normalizedText.contains('akilli bileklik') ||
                              normalizedText.contains('smartwatch') ||
                              normalizedText.contains('watch gt') ||
                              (normalizedText.contains('watch') && (
                                normalizedText.contains('huawei') ||
                                normalizedText.contains('samsung') ||
                                normalizedText.contains('apple') ||
                                normalizedText.contains('garmin')));
      if (!isSmartWearable) {
        finalCategoryId = 'moda';
        finalSubCategory = 'Saat, Aksesuar & Takı';
      }
    }

    // 7b. Yatak / Yorgan / Mobilya vs. Yapı (Ortopedik yatak, yaylı yatak → ev_yasam)
    if (finalCategoryId == 'yapi_oto') {
      final isBeddingOrFurniture = normalizedText.contains('yatak') ||
                                    normalizedText.contains('yorgan') ||
                                    normalizedText.contains('nevresim') ||
                                    normalizedText.contains('carsaf') ||
                                    normalizedText.contains('çarşaf') ||
                                    normalizedText.contains('yastik') ||
                                    normalizedText.contains('yastık') ||
                                    normalizedText.contains('koltuk takimi') ||
                                    normalizedText.contains('koltuk takımı') ||
                                    normalizedText.contains('gardirop') ||
                                    normalizedText.contains('gardırop') ||
                                    normalizedText.contains('dolap') ||
                                    normalizedText.contains('ortopedik');
      if (isBeddingOrFurniture) {
        finalCategoryId = 'ev_yasam';
        finalSubCategory = 'Mobilya';
      }
    }

    // 8. Yazılım / Lisans / Kurulum Paketleri (Dijital Hizmetler olmalı, Elektronik veya Kitap/Hobi değil)
    final isSoftware = normalizedText.contains('yazilim') ||
                       normalizedText.contains('lisans') ||
                       normalizedText.contains('kurulum paketi') ||
                       normalizedText.contains('antivirus') ||
                       normalizedText.contains('vpn') ||
                       normalizedText.contains('membership') ||
                       normalizedText.contains('abonelik') ||
                       normalizedText.contains('uyelik') ||
                       normalizedText.contains('kod');
    if (isSoftware && (finalCategoryId == 'elektronik' || finalCategoryId == 'kitap_hobi')) {
      finalCategoryId = 'dijital_hizmetler';
      finalSubCategory = 'Abonelik & Yazılım';
    }

    // 9. Lego & Yetişkin Oyuncak / Maket / Puzzle Yönlendirmesi
    // Tüm LEGO'ları (Lego Duplo dahil) ve 18+/Yetişkin/Maket ibaresi barındıran oyuncakları Kitap & Hobi'ye yönlendir
    final hasLego = normalizedText.contains('lego');
    final isAdultToyOrHobby = hasLego ||
                              normalizedText.contains('18+') ||
                              normalizedText.contains('16+') ||
                              normalizedText.contains('14+') ||
                              normalizedText.contains('yetiskin') ||
                              normalizedText.contains('adult') ||
                              normalizedText.contains('maket') ||
                              normalizedText.contains('model kit') ||
                              normalizedText.contains('koleksiyon');

    if (isAdultToyOrHobby && (finalCategoryId == 'anne_bebek' || hasLego)) {
      finalCategoryId = 'kitap_hobi';
      finalSubCategory = 'Kutu Oyunları & Oyuncaklar';
    }

    // 10. Kitap Yayınevi / Banka Kampanyaları Karışıklığı
    // Eğer kategori finans_kampanyalar seçildiyse ama metin yayınevi veya kitap ibareleri barındırıyorsa kitap_hobi olmalı
    if (finalCategoryId == 'finans_kampanyalar') {
      final isBookOrPublishing = normalizedText.contains('yayinlari') ||
                                 normalizedText.contains('yayınları') ||
                                 normalizedText.contains('yayinevi') ||
                                 normalizedText.contains('yayınevi') ||
                                 normalizedText.contains('yayin') ||
                                 normalizedText.contains('yayın') ||
                                 normalizedText.contains('kitap') ||
                                 normalizedText.contains('roman') ||
                                 normalizedText.contains('dergi') ||
                                 normalizedText.contains('basim') ||
                                 normalizedText.contains('baski') ||
                                 normalizedText.contains('yazar');
      if (isBookOrPublishing) {
        finalCategoryId = 'kitap_hobi';
        finalSubCategory = 'Kitap & Dergi';
      }
    }

    // 11. Biberon / Emzirme / Bebek Bebek Ürünleri Karışıklığı
    // Eğer 'biberon', 'emzirme', 'mama isitici' gibi kelimeler geçiyorsa her zaman 'anne_bebek' -> 'Beslenme & Emzirme' olmalı
    final isFeedingOrNursing = normalizedText.contains('biberon') ||
                               normalizedText.contains('baby bottle') ||
                               normalizedText.contains('emzirme') ||
                               normalizedText.contains('breast pump') ||
                               normalizedText.contains('gogus pompasi') ||
                               normalizedText.contains('göğüs pompası') ||
                               normalizedText.contains('mama isitici') ||
                               normalizedText.contains('mama ısıtıcı') ||
                               normalizedText.contains('biberon emzigi') ||
                               normalizedText.contains('biberon emziği') ||
                               normalizedText.contains('emzik') ||
                               normalizedText.contains('emzigi');
    if (isFeedingOrNursing) {
      finalCategoryId = 'anne_bebek';
      finalSubCategory = 'Beslenme & Emzirme';
    }

    // 12. Oyuncak (Barbie, bebek oyuncağı, vb.) / Bebek Odası Karışıklığı
    // 'oyuncak' kelimeleri + tanınmış oyuncak markaları varsa ve kategori anne_bebek ise alt kategori oyuncaklar olmalı
    if (finalCategoryId == 'anne_bebek' && finalSubCategory != 'Beslenme & Emzirme') {
      // Bebek oda/güvenlik ürünleri: telsiz, bebek arabası, bakım çantası vb. varsa dokunma
      final isBabySafetyProduct = normalizedText.contains('telsiz') ||
                                   normalizedText.contains('bebek odasi') ||
                                   normalizedText.contains('bebek odası') ||
                                   normalizedText.contains('guvenligi') ||
                                   normalizedText.contains('güvenliği') ||
                                   normalizedText.contains('oto koltuk') ||
                                   normalizedText.contains('puset') ||
                                   normalizedText.contains('bebek arabasi') ||
                                   normalizedText.contains('bebek arabası') ||
                                   normalizedText.contains('hastane canta') ||
                                   normalizedText.contains('hastane çanta') ||
                                   normalizedText.contains('bakim cantasi') ||
                                   normalizedText.contains('bakım çantası') ||
                                   normalizedText.contains('bebek bakim') ||
                                   normalizedText.contains('bebek bakım');
      final isToyProduct = !isBabySafetyProduct && (
                           normalizedText.contains('barbie') ||
                           normalizedText.contains('oyuncak bebek') ||
                           normalizedText.contains('kiz oyuncag') ||
                           normalizedText.contains('kız oyuncağ') ||
                           normalizedText.contains('oyun seti') ||
                           normalizedText.contains('hot wheels') ||
                           normalizedText.contains('matchbox') ||
                           normalizedText.contains('fisher price') ||
                           normalizedText.contains('fisher-price') ||
                           normalizedText.contains('vtech') ||
                           normalizedText.contains('playmobil'));
      if (isBabySafetyProduct) {
        if (finalSubCategory == 'Bebek & Çocuk Oyuncakları') {
          final isStrollerOrCarSeat = normalizedText.contains('puset') ||
                                       normalizedText.contains('bebek arabasi') ||
                                       normalizedText.contains('bebek arabası') ||
                                       normalizedText.contains('oto koltuk') ||
                                       normalizedText.contains('oto koltuğu') ||
                                       normalizedText.contains('bakim cantasi') ||
                                       normalizedText.contains('bakım çantası');
          if (isStrollerOrCarSeat) {
            finalSubCategory = 'Bebek Arabası & Oto Koltuğu';
          } else {
            finalSubCategory = 'Bebek Odası & Güvenlik';
          }
        }
      } else if (isToyProduct) {
        finalSubCategory = 'Bebek & Çocuk Oyuncakları';
      }
    }

    // 13. Ayakkabı / Terlik / Sandalet Yönlendirmesi (Moda altında ise her zaman Ayakkabı & Çanta olmalı)
    if (finalCategoryId == 'moda' && !isExplicitInvestmentGold) {
      final isFootwear = normalizedText.contains('ayakkabi') ||
                          normalizedText.contains('ayakkabı') ||
                          normalizedText.contains('bot') ||
                          normalizedText.contains('cizme') ||
                          normalizedText.contains('çizme') ||
                          normalizedText.contains('terlik') ||
                          normalizedText.contains('sandalet') ||
                          normalizedText.contains('sneaker') ||
                          normalizedText.contains('babet') ||
                          normalizedText.contains('stiletto') ||
                          normalizedText.contains('topuklu') ||
                          normalizedText.contains('krampon');
      final isBabyPatik = normalizedText.contains('patik') ||
                          normalizedText.contains('bebek patik');
      if (isFootwear && !isBabyPatik) {
        finalSubCategory = 'Ayakkabı & Çanta';
      }
    }

    // 14. Yatak (Mattress/Bed) vs Ev Tekstili (Nevresim, Örtü, Yorgan)
    if (normalizedText.contains('yatak') && finalCategoryId == 'ev_yasam') {
      final isBeddingTextile = normalizedText.contains('ortu') ||
                               normalizedText.contains('örtü') ||
                               normalizedText.contains('koruyucu') ||
                               normalizedText.contains('alez') ||
                               normalizedText.contains('takim') ||
                               normalizedText.contains('takımı') ||
                               normalizedText.contains('nevresim') ||
                               normalizedText.contains('carsaf') ||
                               normalizedText.contains('çarşaf') ||
                               normalizedText.contains('kılıf') ||
                               normalizedText.contains('kilif');
      if (!isBeddingTextile) {
        finalSubCategory = 'Mobilya';
      } else {
        finalSubCategory = 'Ev Tekstili';
      }
    }

    // 15. Bebek Bakım Çantası (Bebek Arabası & Oto Koltuğu olmalı, Bebek Bezi & Islak Mendil değil)
    if (finalCategoryId == 'anne_bebek' && finalSubCategory == 'Bebek Bezi & Islak Mendil') {
      if (normalizedText.contains('canta') || normalizedText.contains('çanta')) {
        finalSubCategory = 'Bebek Arabası & Oto Koltuğu';
      }
    }

    // 16. Çamaşır/Bulaşık Makinesi Deterjanı vs Makinenin Kendisi
    final isDetergentOrSoftener = normalizedText.contains('deterjan') ||
                                   normalizedText.contains('yumusatici') ||
                                   normalizedText.contains('yumuşatıcı') ||
                                   normalizedText.contains('fairy') ||
                                   normalizedText.contains('finish') ||
                                   normalizedText.contains('calgon') ||
                                   ((normalizedText.contains('kapsul') || normalizedText.contains('kapsül')) && !normalizedText.contains('kahve') && !normalizedText.contains('cay') && !normalizedText.contains('çay') && !normalizedText.contains('espresso') && !normalizedText.contains('makine')) ||
                                   (normalizedText.contains('tablet') && (normalizedText.contains('bulasik') || normalizedText.contains('bulaşık') || normalizedText.contains('deterjan') || normalizedText.contains('makine') || normalizedText.contains('fairy') || normalizedText.contains('finish') || normalizedText.contains('calgon')));
                                    
    if (isDetergentOrSoftener) {
      final isBabyProduct = normalizedText.contains('bebek') || normalizedText.contains('baby');
      if (!isBabyProduct) {
        finalCategoryId = 'supermarket';
        finalSubCategory = 'Deterjan & Temizlik';
      }
    }

    // 17. Çay/Kahve Makinesi / Öğütücüsü vs Çay/Kahve Gıda Ürünü
    if (finalCategoryId == 'supermarket' && finalSubCategory == 'Gıda Ürünleri') {
      final hasMachineWord = normalizedText.contains('makinesi') ||
                             normalizedText.contains('makineleri') ||
                             normalizedText.contains('makine') ||
                             normalizedText.contains('maker') ||
                             normalizedText.contains('ogutucu') ||
                             normalizedText.contains('öğütücü') ||
                             normalizedText.contains('degirmen') ||
                             normalizedText.contains('değirmen') ||
                             normalizedText.contains('grinder');
      if (hasMachineWord && (normalizedText.contains('kahve') || normalizedText.contains('cay') || normalizedText.contains('çay') || normalizedText.contains('nespresso') || normalizedText.contains('espresso'))) {
        finalCategoryId = 'elektronik';
        finalSubCategory = 'Beyaz Eşya & Küçük Ev Aletleri';
      }
    }

    // 18. El Kremi / Vücut Kremi vs Saç Bakımı (Cilt & Yüz Bakımı olmalı)
    if (finalCategoryId == 'kozmetik' && finalSubCategory == 'Saç Bakımı') {
      final isSkinCare = normalizedText.contains('el kremi') ||
                         normalizedText.contains('el bakim') ||
                         normalizedText.contains('vucut kremi') ||
                         normalizedText.contains('vücut kremi') ||
                         normalizedText.contains('vucut losyonu') ||
                         normalizedText.contains('vücut losyonu') ||
                         normalizedText.contains('el losyonu');
      if (isSkinCare) {
        finalSubCategory = 'Cilt & Yüz Bakımı';
      }
    }

    // 19. Her Türlü Kulaklık -> Telefon & Aksesuarları
    if (finalCategoryId != 'elektronik' || finalSubCategory != 'Telefon & Aksesuarları') {
      final hasKulaklik = normalizedText.contains('kulaklik') ||
                           normalizedText.contains('kulaklık') ||
                           normalizedText.contains('headset') ||
                           normalizedText.contains('kulakligi') ||
                           normalizedText.contains('kulaklığı');
      if (hasKulaklik && !normalizedText.contains('oyuncak') && !normalizedText.contains('stand') && !normalizedText.contains('askı') && !normalizedText.contains('aski')) {
        finalCategoryId = 'elektronik';
        finalSubCategory = 'Telefon & Aksesuarları';
      }
    }

    // 20. Klavye / Mouse -> Bilgisayar & Tablet
    if (finalCategoryId != 'elektronik' || finalSubCategory != 'Bilgisayar & Tablet') {
      final hasKeyboardOrMouse = normalizedText.contains('klavye') ||
                                 normalizedText.contains('klavyesi') ||
                                 normalizedText.contains('mouse') ||
                                 normalizedText.contains('oyuncu faresi') ||
                                 normalizedText.contains('kablolu fare') ||
                                 normalizedText.contains('kablosuz fare');
      if (hasKeyboardOrMouse && !normalizedText.contains('oyuncak')) {
        finalCategoryId = 'elektronik';
        finalSubCategory = 'Bilgisayar & Tablet';
      }
    }

    // 21. Bebek Islak Mendili vs Normal Islak Mendil
    if (finalCategoryId == 'supermarket' && finalSubCategory == 'Kağıt Ürünleri') {
      final hasWetWipes = normalizedText.contains('islak mendil') ||
                          normalizedText.contains('ıslak mendil') ||
                          normalizedText.contains('islak havlu') ||
                          normalizedText.contains('ıslak havlu');
      if (hasWetWipes) {
        final isBabyWipes = normalizedText.contains('bebek') ||
                            normalizedText.contains('baby') ||
                            normalizedText.contains('dalin') ||
                            normalizedText.contains('uni baby');
        if (isBabyWipes) {
          finalCategoryId = 'anne_bebek';
          finalSubCategory = 'Bebek Bezi & Islak Mendil';
        }
      }
    }

    // 22. Gimbal / Sabitleyici -> Fotoğraf & Kamera
    if (finalCategoryId != 'elektronik' || finalSubCategory != 'Fotoğraf & Kamera') {
      final hasGimbal = normalizedText.contains('gimbal') ||
                        normalizedText.contains('sabitleyici') ||
                        normalizedText.contains('sabitleyiciler') ||
                        normalizedText.contains('stabilizer');
      if (hasGimbal && !normalizedText.contains('oyuncak')) {
        finalCategoryId = 'elektronik';
        finalSubCategory = 'Fotoğraf & Kamera';
      }
    }

    return {
      'categoryId': finalCategoryId,
      'subCategory': finalSubCategory,
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

  /// Basit Türkçe gövdeleyici (stemmer)
  static String _stem(String word) {
    if (word.length <= 3) return word;
    String w = word;
    if (w.endsWith('leri') || w.endsWith('lari')) {
      w = w.substring(0, w.length - 4);
    } else if (w.endsWith('ler') || w.endsWith('lar')) {
      w = w.substring(0, w.length - 3);
    } else if (w.endsWith('si') || w.endsWith('su')) {
      w = w.substring(0, w.length - 2);
    }
    
    if (w.endsWith('i') || w.endsWith('u')) {
      w = w.substring(0, w.length - 1);
    }
    
    if (w.endsWith('g')) {
      w = w.substring(0, w.length - 1) + 'k';
    }
    return w;
  }
}
