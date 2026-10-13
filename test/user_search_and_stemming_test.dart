import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/deal_search_engine.dart';
import 'package:sicak_firsatlar/models/user.dart';

void main() {
  group('FS-20 User Search Keywords & Gökay Normalization Tests', () {
    test('"Gökay" için üretilen searchKeywords "gokay", "gok", "go" içermelidir', () {
      final keywords = DealSearchEngine.generateUserSearchKeywords(
        username: 'Gökay',
        displayName: 'Gökay ALEMDAR',
      );

      // Tam kelime ve Türkçe ASCII normalize karşılığı
      expect(keywords.contains('gokay'), isTrue, reason: '"gokay" anahtarı bulunmalı');
      expect(keywords.contains('alemdar'), isTrue, reason: '"alemdar" anahtarı bulunmalı');

      // Prefix (edge n-gram) kontrolleri
      expect(keywords.contains('go'), isTrue, reason: '"go" prefixi bulunmalı');
      expect(keywords.contains('gok'), isTrue, reason: '"gok" prefixi bulunmalı');
      expect(keywords.contains('goka'), isTrue, reason: '"goka" prefixi bulunmalı');
      expect(keywords.contains('al'), isTrue, reason: '"al" prefixi bulunmalı');
      expect(keywords.contains('alem'), isTrue, reason: '"alem" prefixi bulunmalı');

      // Birleşik isim n-gram'ı ve boşluklu tam isim
      expect(keywords.contains('gokayalemdar'), isTrue);
      expect(keywords.contains('gokay alemdar'), isTrue);
    });

    test('Kullanıcı "gokay" veya "Gökay" arattığında normalizeText ile keywords eşleşmelidir', () {
      final userKeywords = DealSearchEngine.generateUserSearchKeywords(
        username: 'Gökay',
        displayName: 'Gökay ALEMDAR',
      );

      // Farklı sorgu biçimlerinin normalize edilmiş halleri
      final query1 = DealSearchEngine.normalizeText('gokay');
      final query2 = DealSearchEngine.normalizeText('Gökay');
      final query3 = DealSearchEngine.normalizeText('GÖKAY');
      final query4 = DealSearchEngine.normalizeText('gok');
      final query5 = DealSearchEngine.normalizeText('GÖK');
      final query6 = DealSearchEngine.normalizeText('alemdar');

      expect(userKeywords.contains(query1), isTrue);
      expect(userKeywords.contains(query2), isTrue);
      expect(userKeywords.contains(query3), isTrue);
      expect(userKeywords.contains(query4), isTrue);
      expect(userKeywords.contains(query5), isTrue);
      expect(userKeywords.contains(query6), isTrue);
    });

    test('Alt çizgili ve karmaşık kullanıcı adlarında kelime ayrıştırma', () {
      final keywords = DealSearchEngine.generateUserSearchKeywords(
        username: 'firsat_avcisi_61',
        nickname: 'Avcı Ali',
      );

      expect(keywords.contains('firsat'), isTrue);
      expect(keywords.contains('avcisi'), isTrue);
      expect(keywords.contains('avci'), isTrue);
      expect(keywords.contains('ali'), isTrue);
    });

    test('rankUsers sıralama motoru doğrulaması', () {
      final users = [
        {
          'id': 'user2',
          'name': 'Gökhan Kaya',
          'username': 'gokhankaya',
          'isBot': false,
          'points': 100,
          'dealCount': 5,
        },
        {
          'id': 'botkolik',
          'name': 'Botkolik',
          'username': 'botkolik',
          'isBot': true,
          'points': 0,
          'dealCount': 0,
        },
        {
          'id': 'user1',
          'name': 'Gökay Alemdar',
          'username': 'gokay',
          'isBot': false,
          'points': 50,
          'dealCount': 2,
        },
      ];

      final ranked = DealSearchEngine.rankUsers(users, 'gokay');

      // Botkolik daima en başta
      expect(ranked[0]['id'], equals('botkolik'));
      // İkinci sırada tam eşleşen 'gokay' kullanıcısı
      expect(ranked[1]['id'], equals('user1'));
      // Üçüncü sırada kısmi eşleşen 'gokhankaya'
      expect(ranked[2]['id'], equals('user2'));
    });
  });

  group('FS-20 Turkish Suffix Stemming Tests', () {
    test('Çoğul ekleri (-lar, -ler) köke ayrıştırılmalıdır', () {
      expect(DealSearchEngine.stemTurkishWord('kulakliklar'), contains('kulaklik'));
      expect(DealSearchEngine.stemTurkishWord('firsatlar'), contains('firsat'));
      expect(DealSearchEngine.stemTurkishWord('telefonlar'), contains('telefon'));
    });

    test('İyelik ve tamlanan ekleri (-si, -su, -i) ayrıştırılmalıdır', () {
      expect(DealSearchEngine.stemTurkishWord('supurgesi'), contains('supurge'));
      expect(DealSearchEngine.stemTurkishWord('indirimi'), contains('indirim'));
    });

    test('tokenize saf ve kök varyantlı ayrıştırmayı doğru yapmalıdır', () {
      final rawTokens = DealSearchEngine.tokenize('robot süpürgeler ve kulaklıklar');
      expect(rawTokens, equals(['robot', 'supurgeler', 've', 'kulakliklar']));

      final tokensWithStems = DealSearchEngine.tokenize('robot süpürgeler ve kulaklıklar', includeStems: true);
      expect(tokensWithStems, contains('supurgeler'));
      expect(tokensWithStems, contains('supurge'));
      expect(tokensWithStems, contains('kulakliklar'));
      expect(tokensWithStems, contains('kulaklik'));
    });
  });

  group('AppUser Model searchKeywords Serialization Tests', () {
    test('AppUser searchKeywords toFirestore ve copyWith ile güvenle korunmalıdır', () {
      final user = AppUser(
        uid: 'test_uid',
        username: 'Gökay',
        profileImageUrl: 'avatar.webp',
        searchKeywords: ['gokay', 'go', 'gok'],
      );

      final map = user.toFirestore();
      expect(map['searchKeywords'], equals(['gokay', 'go', 'gok']));

      final copied = user.copyWith(
        nickname: 'Gök',
      );
      expect(copied.searchKeywords, equals(['gokay', 'go', 'gok']));
    });
  });

  group('FS-20 Resilient Fallback Prefix Variants Tests', () {
    test('"gokay" arandığında hem ASCII hem Türkçe "Gökay" varyantları üretilmelidir', () {
      final variants = DealSearchEngine.generateFallbackPrefixVariants('gokay');
      expect(variants, contains('gokay'));
      expect(variants, contains('Gokay'));
      expect(variants, contains('Gökay'));
      expect(variants, contains('gökay'));
    });

    test('"Gökay" arandığında tersine hem Türkçe hem ASCII "Gokay" varyantları üretilmelidir', () {
      final variants = DealSearchEngine.generateFallbackPrefixVariants('Gökay');
      expect(variants, contains('Gökay'));
      expect(variants, contains('gökay'));
      expect(variants, contains('Gokay'));
      expect(variants, contains('gokay'));
    });

    test('"sukru" ve "ismail" için Türkçe harf dönüşümleri doğru çalışmalıdır', () {
      final sukruVariants = DealSearchEngine.generateFallbackPrefixVariants('sukru');
      expect(sukruVariants, contains('Şükrü'));

      final ismailVariants = DealSearchEngine.generateFallbackPrefixVariants('ismail');
      expect(ismailVariants, contains('İsmail'));
    });
  });
}
