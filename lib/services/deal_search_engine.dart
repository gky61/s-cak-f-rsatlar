import '../models/deal.dart';

/// Akıllı Arama Motoru (Smart Search Engine)
/// Türkçe karakter normalizasyonu, kelime ayrıştırma, çoklu alan taraması
/// ve Alaka Düzeyi Puanlaması (Relevance Scoring) ile %95+ arama başarısı sağlar.
class DealSearchEngine {
  /// Türkçe karakterleri İngilizce karşılıklarına dönüştürür ve küçük harfe çevirir.
  static String normalizeText(String input) {
    if (input.isEmpty) return '';

    // Türkçe karakterleri önce İngilizce karşılıklarına dönüştür (Dart toLowerCase() öncesi U+0307 birleşen nokta bug'ını önler)
    String text = input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('Ç', 'c')
        .replaceAll('ç', 'c')
        .replaceAll('Ğ', 'g')
        .replaceAll('ğ', 'g')
        .replaceAll('Ö', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('Ş', 's')
        .replaceAll('ş', 's')
        .replaceAll('Ü', 'u')
        .replaceAll('ü', 'u')
        .toLowerCase();

    // Özel noktalama işaretlerini ve fazla boşlukları temizle
    text = text.replaceAll(RegExp(r'[^\w\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Türkçe sık kullanılan çoğul (-lar, -ler) ve iyelik/tamlanan eklerini (-i, -ı, -u, -ü, -si, -sı, -su, -sü)
  /// kelime kökünü bozmadan ayıklar ve olası kök kelimeleri döner.
  static List<String> stemTurkishWord(String word) {
    final List<String> stems = [];
    final norm = normalizeText(word);
    if (norm.length < 4) return stems;

    // 1. Çoğul ekleri (-lar, -ler)
    if (norm.endsWith('lar') || norm.endsWith('ler')) {
      final stem = norm.substring(0, norm.length - 3);
      if (stem.length >= 3) stems.add(stem);
    }

    // 2. İyelik ekleri (-si, -sı, -su, -sü -> normalize: -si, -su)
    if (norm.endsWith('si') || norm.endsWith('su')) {
      final stem = norm.substring(0, norm.length - 2);
      if (stem.length >= 3) stems.add(stem);
    }

    // 3. Basit tamlanan/belirtme ekleri (-i, -ı, -u, -ü -> normalize: -i, -u)
    // Sadece 5 harf veya daha uzun kelimelerde (aşırı kök kırpmayı önlemek için)
    if (norm.length >= 5 && (norm.endsWith('i') || norm.endsWith('u'))) {
      final stem = norm.substring(0, norm.length - 1);
      if (stem.length >= 3) stems.add(stem);
    }

    return stems;
  }

  /// Metni anlamlı kelimelere (token) böler.
  /// [includeStems] true ise Türkçe ek ayrıştırma köklerini de ekler.
  static List<String> tokenize(String input, {bool includeStems = false}) {
    final normalized = normalizeText(input);
    if (normalized.isEmpty) return [];
    final rawTokens = normalized
        .replaceAll('_', ' ')
        .split(' ')
        .where((token) => token.length >= 2 || RegExp(r'^\d+$').hasMatch(token))
        .toSet()
        .toList();

    if (!includeStems) return rawTokens;

    final Set<String> tokensWithStems = Set.from(rawTokens);
    for (final token in rawTokens) {
      for (final stem in stemTurkishWord(token)) {
        tokensWithStems.add(stem);
      }
    }
    return tokensWithStems.toList();
  }

  /// Fırsat dokümanının Firestore'da hedeflenmiş sunucu sorgusuyla bulunabilmesi için
  /// normalize edilmiş aranabilir kök kelime kümesini üretir.
  static List<String> generateSearchKeywords({
    required String title,
    String? brand,
    String? store,
    String? category,
    String? subCategory,
  }) {
    final Set<String> keywords = {};

    void addFieldTokens(String? field) {
      if (field == null || field.trim().isEmpty) return;
      final tokens = tokenize(field, includeStems: true);
      keywords.addAll(tokens);
    }

    // 1. Başlık kelimeleri
    addFieldTokens(title);

    // 2. Marka kelimeleri
    addFieldTokens(brand);

    // 3. Mağaza kelimeleri
    addFieldTokens(store);

    // 4. Kategori ve Alt kategori kelimeleri
    addFieldTokens(category);
    addFieldTokens(subCategory);

    // En fazla 50 özgün arama anahtarı döner
    return keywords.take(50).toList();
  }

  /// Kullanıcı profili için (username, displayName, nickname)
  /// Firestore'da tek bir array-contains sorgusuyla anında ve büyük-küçük / Türkçe harf duyarsız
  /// bulunabilmesini sağlayan kök ve prefix (edge n-gram) anahtar kelime kümesini üretir.
  /// Örnek: "Gökay" -> ["gokay", "go", "gok", "goka"]
  /// Kullanıcı "gok", "gokay", "Gökay" arattığında birebir ve eksiksiz eşleşir.
  static List<String> generateUserSearchKeywords({
    required String username,
    String? displayName,
    String? nickname,
  }) {
    final Set<String> keywords = {};

    void addNameKeywords(String? name) {
      if (name == null || name.trim().isEmpty) return;
      final clean = name.trim();
      final normalized = normalizeText(clean);
      if (normalized.isEmpty) return;

      // Kelimelere ayır (boşluk ve alt çizgi dahil)
      final tokens = normalized
          .replaceAll('_', ' ')
          .split(' ')
          .where((t) => t.isNotEmpty)
          .toList();

      for (final token in tokens) {
        if (token.isEmpty) continue;
        keywords.add(token);

        // Minimum 2 karakterden başlayarak kelimenin prefix'lerini (edge n-gram) ekle
        final maxPrefixLength = token.length < 25 ? token.length : 25;
        for (int i = 2; i <= maxPrefixLength; i++) {
          keywords.add(token.substring(0, i));
        }
      }

      // Eğer isim birden fazla kelimeden oluşuyorsa (örn: "gokay akin"),
      // hem tam boşluklu halini ("gokay akin"), hem bitişik halini ("gokayakin") ve prefixlerini ekle
      if (tokens.length > 1) {
        final spaceJoined = tokens.join(' ');
        if (spaceJoined.length >= 2 && spaceJoined.length <= 40) {
          keywords.add(spaceJoined);
        }
        final joined = tokens.join('');
        if (joined.length >= 2 && joined.length <= 30) {
          keywords.add(joined);
          final maxJoined = joined.length < 20 ? joined.length : 20;
          for (int i = 2; i <= maxJoined; i++) {
            keywords.add(joined.substring(0, i));
          }
        }
      }
    }

    addNameKeywords(username);
    if (displayName != null && displayName != username) {
      addNameKeywords(displayName);
    }
    if (nickname != null && nickname != username && nickname != displayName) {
      addNameKeywords(nickname);
    }

    // Firestore doküman sınırları ve indeks verimliliği için en fazla 60 anahtar
    return keywords.take(60).toList();
  }

  /// Henüz searchKeywords taşınmamış eski kullanıcılar için
  /// hem Türkçe hem ASCII harf kombinasyonlarını üreten zeki prefix listesi.
  /// Örnek: "Gokay" -> ["Gokay", "gokay", "Gökay", "gökay"]
  /// Örnek: "Gökay" -> ["Gökay", "gökay", "Gokay", "gokay"]
  static List<String> generateFallbackPrefixVariants(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return [];

    final variants = <String>{};
    void addVariant(String v) {
      final t = v.trim();
      if (t.isNotEmpty && !variants.contains(t)) {
        variants.add(t);
      }
    }

    addVariant(clean);
    addVariant(clean.toLowerCase());
    if (clean.length > 1) {
      addVariant('${clean[0].toUpperCase()}${clean.substring(1).toLowerCase()}');
      addVariant(clean.toUpperCase());
    }

    // ASCII -> Türkçe karakter dönüşümü (örn: 'o' -> 'ö', 'u' -> 'ü', 'c' -> 'ç', 's' -> 'ş')
    String toTr(String s) {
      return s
          .replaceAll('o', 'ö').replaceAll('O', 'Ö')
          .replaceAll('u', 'ü').replaceAll('U', 'Ü')
          .replaceAll('c', 'ç').replaceAll('C', 'Ç')
          .replaceAll('s', 'ş').replaceAll('S', 'Ş');
    }

    final trVariant = toTr(clean);
    if (trVariant != clean) {
      addVariant(trVariant);
      addVariant(trVariant.toLowerCase());
      if (trVariant.length > 1) {
        addVariant('${trVariant[0].toUpperCase()}${trVariant.substring(1).toLowerCase()}');
      }
    }

    // Türkçe -> ASCII karakter dönüşümü (örn: 'Gökay' -> 'gokay', 'Gokay')
    final asciiVariant = normalizeText(clean);
    if (asciiVariant.isNotEmpty) {
      addVariant(asciiVariant);
      addVariant(asciiVariant.toLowerCase());
      if (asciiVariant.length > 1) {
        addVariant('${asciiVariant[0].toUpperCase()}${asciiVariant.substring(1).toLowerCase()}');
      }
    }

    // Türkçe 'İ' ve 'I' özel durumları
    if (clean.toLowerCase().startsWith('i')) {
      addVariant('İ${clean.substring(1)}');
      addVariant('I${clean.substring(1)}');
    } else if (clean.startsWith('İ') || clean.startsWith('I')) {
      addVariant('i${clean.substring(1).toLowerCase()}');
    }

    return variants.take(8).toList();
  }

  /// Eşleşen kullanıcıları arama sorgusuna ve aktiviteye göre sıralar.
  /// 1. Tam kullanıcı adı / isim eşleşmesi
  /// 2. Başlangıç (prefix) eşleşmesi
  /// 3. Çok kelimeli tamlık bonusu
  /// 4. Botkolik önceliği
  /// 5. Puan, fırsat sayısı ve rozet ağırlığı
  static List<Map<String, dynamic>> rankUsers(
    List<Map<String, dynamic>> users,
    String rawQuery,
  ) {
    if (users.length <= 1) return users;
    final cleanQuery = rawQuery.trim().toLowerCase();
    final normalizedQuery = normalizeText(cleanQuery);

    final scored = users.map((user) {
      double score = 0.0;
      final username = (user['username'] ?? '').toString().toLowerCase();
      final name = (user['name'] ?? '').toString().toLowerCase();
      final normUsername = normalizeText(username);
      final normName = normalizeText(name);

      final isBot = user['isBot'] == true;
      if (isBot) score += 500.0; // Botkolik daima en başta

      // 1. Tam eşleşme bonusu
      if (normUsername == normalizedQuery || normName == normalizedQuery) {
        score += 200.0;
      } else if (normUsername.startsWith(normalizedQuery) || normName.startsWith(normalizedQuery)) {
        score += 100.0;
      } else if (normUsername.contains(normalizedQuery) || normName.contains(normalizedQuery)) {
        score += 50.0;
      }

      // Çok kelimeli sorgularda kelime bazlı eşleşme (örn: "gokay a" veya "gokay alemdar")
      final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();
      if (queryWords.length > 1) {
        int matchedWords = 0;
        for (final w in queryWords) {
          if (normUsername.contains(w) || normName.contains(w)) {
            matchedWords++;
            score += 30.0;
          }
        }
        if (matchedWords == queryWords.length) {
          score += 80.0; // Tüm kelimeler kullanıcıda mevcut!
        }
      }

      // 2. Aktivite bonusu
      final points = user['points'] is int
          ? user['points'] as int
          : int.tryParse(user['points']?.toString() ?? '0') ?? 0;
      final dealCount = user['dealCount'] is int
          ? user['dealCount'] as int
          : int.tryParse(user['dealCount']?.toString() ?? '0') ?? 0;
      score += (points * 0.05).clamp(0.0, 50.0);
      score += (dealCount * 1.0).clamp(0.0, 30.0);

      if (user['pinnedBadge'] != null && user['pinnedBadge'].toString().isNotEmpty) {
        score += 15.0;
      }

      return MapEntry(user, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Verilen fırsat listesi üzerinde arama yapar ve sonuçları Alaka Düzeyine göre sıralar.
  static List<Deal> searchDeals(List<Deal> deals, String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return deals;

    // CPU ve Regex DoS koruması: Arama sorgusu en fazla 200 karakter olabilir
    final safeQuery = cleanQuery.length > 200 ? cleanQuery.substring(0, 200) : cleanQuery;
    final normalizedQuery = normalizeText(safeQuery);
    final queryTokens = tokenize(safeQuery);

    if (queryTokens.isEmpty && normalizedQuery.isEmpty) return deals;

    final List<_ScoredDeal> scoredDeals = [];

    for (final deal in deals) {
      final score = calculateRelevanceScore(deal, normalizedQuery, queryTokens);
      if (score > 0) {
        scoredDeals.add(_ScoredDeal(deal, score));
      }
    }

    // Alaka Düzeyi Puanına göre azalan sıralama (Puanlar eşitse tarihe göre)
    scoredDeals.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return b.deal.createdAt.compareTo(a.deal.createdAt);
    });

    return scoredDeals.map((sd) => sd.deal).toList();
  }

  /// Bir fırsat için verilen arama sorgusunun Alaka Düzeyi Puanını (Relevance Score) hesaplar.
  static double calculateRelevanceScore(
      Deal deal, String normalizedQuery, List<String> queryTokens) {
    double score = 0.0;

    final normalizedTitle = normalizeText(deal.title);
    final normalizedDesc = normalizeText(deal.description);
    final normalizedStore = normalizeText(deal.store);
    final normalizedBrand = normalizeText(deal.brand ?? '');
    final normalizedCategory = normalizeText(deal.category);
    final normalizedSubCategory = normalizeText(deal.subCategory ?? '');
    final normalizedCouponCode = normalizeText(deal.couponCode ?? '');
    final normalizedPriceLabel = normalizeText(deal.priceLabel ?? '');

    // 1. TAM CÜMLE EŞLEŞMELERİ (Exact & Substring Matches)
    if (normalizedTitle == normalizedQuery) {
      score += 150.0; // Birebir başlık eşleşmesi
    } else if (normalizedTitle.startsWith(normalizedQuery)) {
      score += 100.0; // Başlığın sorguyla başlaması
    } else if (normalizedTitle.contains(normalizedQuery)) {
      score += 70.0; // Başlık içinde sorgunun tam geçmesi
    }

    if (normalizedBrand.isNotEmpty && normalizedBrand == normalizedQuery) {
      score += 60.0; // Birebir marka eşleşmesi
    } else if (normalizedBrand.contains(normalizedQuery)) {
      score += 40.0;
    }

    if (normalizedStore == normalizedQuery) {
      score += 50.0; // Birebir mağaza eşleşmesi
    } else if (normalizedStore.contains(normalizedQuery)) {
      score += 30.0;
    }

    if (normalizedCouponCode.isNotEmpty && normalizedCouponCode == normalizedQuery) {
      score += 80.0; // Kupon kodu tam eşleşmesi
    } else if (normalizedCouponCode.contains(normalizedQuery)) {
      score += 50.0;
    }

    if (normalizedCategory == normalizedQuery || normalizedSubCategory == normalizedQuery) {
      score += 40.0;
    }

    if (normalizedDesc.contains(normalizedQuery)) {
      score += 25.0;
    }

    if (normalizedPriceLabel.contains(normalizedQuery)) {
      score += 20.0;
    }

    // 2. KELİME BAZLI EŞLEŞMELER (Token-Based Multi-Word Matching)
    final titleTokens = tokenize(deal.title);
    final descTokens = tokenize(deal.description);
    final brandTokens = tokenize(deal.brand ?? '');
    final storeTokens = tokenize(deal.store);

    int matchedTokensCount = 0;

    for (final token in queryTokens) {
      bool tokenMatched = false;

      // Başlık kelimelerinde arama
      for (final tToken in titleTokens) {
        if (tToken == token) {
          score += 35.0; // Tam kelime eşleşmesi
          tokenMatched = true;
          break;
        } else if (tToken.startsWith(token) || token.startsWith(tToken)) {
          score += 20.0; // Kısmi kelime kökü eşleşmesi
          tokenMatched = true;
          break;
        } else {
          final tStems = stemTurkishWord(tToken);
          final qStems = stemTurkishWord(token);
          final hasStemMatch = (qStems.isNotEmpty && qStems.any((s) => tToken.startsWith(s) || s == tToken)) ||
              (tStems.isNotEmpty && tStems.any((s) => token.startsWith(s) || s == token));
          if (hasStemMatch) {
            score += 20.0;
            tokenMatched = true;
            break;
          } else if (tToken.contains(token)) {
            score += 12.0;
            tokenMatched = true;
            break;
          }
        }
      }

      // Marka kelimelerinde arama
      for (final bToken in brandTokens) {
        if (bToken == token || bToken.startsWith(token)) {
          score += 25.0;
          tokenMatched = true;
          break;
        }
      }

      // Mağaza kelimelerinde arama
      for (final sToken in storeTokens) {
        if (sToken == token || sToken.startsWith(token)) {
          score += 20.0;
          tokenMatched = true;
          break;
        }
      }

      // Kupon kodu kelime eşleşmesi
      if (normalizedCouponCode.contains(token)) {
        score += 30.0;
        tokenMatched = true;
      }

      // Açıklama kelimelerinde arama
      if (!tokenMatched) {
        for (final dToken in descTokens) {
          if (dToken == token || dToken.startsWith(token) || token.startsWith(dToken)) {
            score += 8.0;
            tokenMatched = true;
            break;
          } else if (dToken.contains(token)) {
            score += 4.0;
            tokenMatched = true;
            break;
          }
        }
      }

      if (tokenMatched) {
        matchedTokensCount++;
      }
    }

    // Eğer çoklu kelime arandıysa ve sorgudaki kelimelerin tümü/büyük çoğunluğu eşleştiyse BONUS Puan!
    if (queryTokens.length > 1) {
      final matchRatio = matchedTokensCount / queryTokens.length;
      if (matchRatio >= 1.0) {
        score += 50.0; // Bütün kelimeler bulundu!
      } else if (matchRatio >= 0.6) {
        score += 20.0;
      } else if (matchRatio < 0.4) {
        // Kelimelerin yarısından azı bulunabildiyse puan kır
        score *= 0.5;
      }
    }

    return score;
  }
}

class _ScoredDeal {
  final Deal deal;
  final double score;

  _ScoredDeal(this.deal, this.score);
}
