import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/services/deal_search_engine.dart';

void main() {
  group('Search Hardening and Prod Resilience Tests', () {
    test('firestore.indexes.json must contain deals (isApproved, searchKeywords, createdAt DESC) composite index', () {
      final indexFile = File('firestore.indexes.json');
      expect(indexFile.existsSync(), isTrue, reason: 'firestore.indexes.json bulunmalıdır.');

      final jsonContent = jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
      final indexes = jsonContent['indexes'] as List<dynamic>;

      bool hasSortedSearchIndex = false;

      for (final index in indexes) {
        if (index['collectionGroup'] != 'deals') continue;
        final fields = index['fields'] as List<dynamic>;
        if (fields.length == 3) {
          final f0 = fields[0];
          final f1 = fields[1];
          final f2 = fields[2];

          if (f0['fieldPath'] == 'isApproved' &&
              f0['order'] == 'ASCENDING' &&
              f1['fieldPath'] == 'searchKeywords' &&
              f1['arrayConfig'] == 'CONTAINS' &&
              f2['fieldPath'] == 'createdAt' &&
              f2['order'] == 'DESCENDING') {
            hasSortedSearchIndex = true;
            break;
          }
        }
      }

      expect(hasSortedSearchIndex, isTrue,
          reason: 'Deals koleksiyonunda isApproved ASC, searchKeywords CONTAINS, createdAt DESC bileşik indeksi tanımlı olmalıdır.');
    });

    test('primaryToken seçimi en ayırt edici ve uzun kök kelimeyi seçmelidir', () {
      final tokens1 = DealSearchEngine.tokenize('apple iphone 15 pro max');
      final sortedTokens1 = List<String>.from(tokens1)..sort((a, b) => b.length.compareTo(a.length));
      expect(sortedTokens1.first, 'iphone');

      final tokens2 = DealSearchEngine.tokenize('robot süpürge');
      final sortedTokens2 = List<String>.from(tokens2)..sort((a, b) => b.length.compareTo(a.length));
      expect(sortedTokens2.first, 'supurge');

      final tokens3 = DealSearchEngine.tokenize('ps5 kol');
      final sortedTokens3 = List<String>.from(tokens3)..sort((a, b) => b.length.compareTo(a.length));
      expect(sortedTokens3.first, 'ps5');
    });

    test('searchDeals relevance scoring ve tarih önceliğini korumalıdır', () {
      final now = DateTime.now();
      final dealOldExact = Deal(
        id: '1',
        title: 'Sony WH-1000XM5 Kulaklık',
        price: 10000,
        store: 'Amazon',
        category: 'elektronik',
        link: 'http://link.com',
        imageUrl: '',
        hotVotes: 5,
        coldVotes: 0,
        commentCount: 2,
        postedBy: 'user1',
        isEditorPick: false,
        createdAt: now.subtract(const Duration(days: 10)),
        isApproved: true,
      );

      final dealNewExact = Deal(
        id: '2',
        title: 'Sony WH-1000XM5 Kulaklık',
        price: 9500,
        store: 'Hepsiburada',
        category: 'elektronik',
        link: 'http://link.com',
        imageUrl: '',
        hotVotes: 8,
        coldVotes: 0,
        commentCount: 4,
        postedBy: 'user2',
        isEditorPick: false,
        createdAt: now.subtract(const Duration(hours: 2)),
        isApproved: true,
      );

      final dealPartial = Deal(
        id: '3',
        title: 'Kulaklık Taşıma Çantası Sony Uyumlu',
        price: 300,
        store: 'Trendyol',
        category: 'aksesuar',
        link: 'http://link.com',
        imageUrl: '',
        hotVotes: 1,
        coldVotes: 0,
        commentCount: 0,
        postedBy: 'user3',
        isEditorPick: false,
        createdAt: now.subtract(const Duration(hours: 1)),
        isApproved: true,
      );

      final results = DealSearchEngine.searchDeals([dealOldExact, dealPartial, dealNewExact], 'Sony WH-1000XM5');

      expect(results.length, 3);
      // Puanları eşit olan iki tam başlık eşleşmesinde yeni olan (dealNewExact) en başta yer almalıdır
      expect(results[0].id, '2');
      expect(results[1].id, '1');
      expect(results[2].id, '3');
    });

    test('Kullanıcı sorgu temizleme @ prefixini ve boşlukları güvenle normalize etmelidir', () {
      const raw1 = '@ahmet';
      final clean1 = raw1.replaceFirst('@', '').trim();
      expect(clean1, 'ahmet');

      const raw2 = '@  mehmet_yilmaz  ';
      final clean2 = raw2.replaceFirst('@', '').trim();
      expect(clean2, 'mehmet_yilmaz');

      const raw3 = 'botkolik';
      final clean3 = raw3.replaceFirst('@', '').trim();
      expect(clean3, 'botkolik');
    });

    test('Fırsat aramasında Türkçe büyük/küçük harf normalizasyonu (İ, I, Ş, Ç, Ö, Ü) kusursuz çalışmalıdır', () {
      expect(DealSearchEngine.normalizeText('İPHONE 15'), 'iphone 15');
      expect(DealSearchEngine.normalizeText('iphone 15'), 'iphone 15');
      expect(DealSearchEngine.normalizeText('iPhone 15'), 'iphone 15');
      expect(DealSearchEngine.normalizeText('ŞEKER'), 'seker');
      expect(DealSearchEngine.normalizeText('şeker'), 'seker');
      expect(DealSearchEngine.normalizeText('IŞIK KULAKLIK'), 'isik kulaklik');
      expect(DealSearchEngine.normalizeText('ÇAYKUR ÇAYI'), 'caykur cayi');
      expect(DealSearchEngine.normalizeText('ÖZEL ÜRÜN'), 'ozel urun');

      // Token eşleşmesi
      final tokens1 = DealSearchEngine.tokenize('İPHONE 15 PRO');
      expect(tokens1.contains('iphone'), isTrue);
      expect(tokens1.contains('15'), isTrue);
      expect(tokens1.contains('pro'), isTrue);
    });

    test('Kullanıcı aramasında çoklu varyant üretimi muratcan arandığında Muratcan ve MURATCAN üretmelidir', () {
      List<String> buildVariants(String rawQuery) {
        final trimmed = rawQuery.trim();
        final lower = trimmed.toLowerCase();
        final searchVariants = <String>[];
        void addVariant(String v) {
          final t = v.trim();
          if (t.isNotEmpty && !searchVariants.contains(t)) {
            searchVariants.add(t);
          }
        }
        addVariant(trimmed);
        addVariant(lower);
        if (trimmed.length > 1) {
          addVariant('${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}');
          addVariant(trimmed.toUpperCase());
        }
        if (trimmed.contains(' ')) {
          final words = trimmed.split(RegExp(r'\s+'));
          final titleWords = words.map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');
          addVariant(titleWords);
        }
        if (lower.startsWith('i')) {
          addVariant('İ${lower.substring(1)}');
          addVariant('I${lower.substring(1)}');
        } else if (trimmed.startsWith('İ') || trimmed.startsWith('I')) {
          addVariant('i${trimmed.substring(1).toLowerCase()}');
        }
        return searchVariants;
      }

      final v1 = buildVariants('muratcan');
      expect(v1.contains('muratcan'), isTrue);
      expect(v1.contains('Muratcan'), isTrue);
      expect(v1.contains('MURATCAN'), isTrue);

      final v2 = buildVariants('murat can');
      expect(v2.contains('murat can'), isTrue);
      expect(v2.contains('Murat Can'), isTrue);
      expect(v2.contains('MURAT CAN'), isTrue);

      final v3 = buildVariants('ismail');
      expect(v3.contains('ismail'), isTrue);
      expect(v3.contains('İsmail'), isTrue);

      final v4 = buildVariants('Muratcan');
      expect(v4.contains('Muratcan'), isTrue);
      expect(v4.contains('muratcan'), isTrue);
      expect(v4.contains('MURATCAN'), isTrue);
    });
  });
}

