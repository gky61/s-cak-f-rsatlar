import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/deal_search_engine.dart';
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/models/message.dart';

void main() {
  group('FAZ 2: FS-20 DealSearchEngine & Keyword Normalization Tests', () {
    test('Turkish characters are normalized correctly (ç, ğ, ı, ö, ş, ü, İ, Ğ)', () {
      const input = 'Şık Çağdaş Ispanaklı Çörek Üzüm İncir';
      final normalized = DealSearchEngine.normalizeText(input);
      expect(normalized, equals('sik cagdas ispanakli corek uzum incir'));
    });

    test('generateSearchKeywords extracts deduplicated roots capped at 50 tokens', () {
      final keywords = DealSearchEngine.generateSearchKeywords(
        title: 'Apple iPhone 15 Pro Max 256GB Titanyum Akıllı Telefon',
        brand: 'Apple',
        store: 'Hepsiburada',
        category: 'Elektronik',
        subCategory: 'Telefon',
      );

      expect(keywords.contains('apple'), isTrue);
      expect(keywords.contains('iphone'), isTrue);
      expect(keywords.contains('15'), isTrue);
      expect(keywords.contains('pro'), isTrue);
      expect(keywords.contains('max'), isTrue);
      expect(keywords.contains('256gb'), isTrue);
      expect(keywords.contains('titanyum'), isTrue);
      expect(keywords.contains('telefon'), isTrue);
      expect(keywords.contains('hepsiburada'), isTrue);
      expect(keywords.contains('elektronik'), isTrue);
      expect(keywords.length, lessThanOrEqualTo(50));
      // No duplicate tokens
      expect(keywords.toSet().length, equals(keywords.length));
    });

    test('Single character tokens are rejected by tokenizer, >=2 or numbers kept', () {
      final tokens = DealSearchEngine.tokenize('a b 5g 4k hp tv x 100');
      expect(tokens.contains('a'), isFalse);
      expect(tokens.contains('b'), isFalse);
      expect(tokens.contains('x'), isFalse);
      expect(tokens.contains('5g'), isTrue);
      expect(tokens.contains('4k'), isTrue);
      expect(tokens.contains('hp'), isTrue);
      expect(tokens.contains('tv'), isTrue);
      expect(tokens.contains('100'), isTrue);
    });

    test('Relevance score calculation rewards multi-word match and exact title matches', () {
      final dealA = Deal(
        id: '1',
        title: 'Sony PlayStation 5 Slim Oyun Konsolu',
        description: 'En ucuz PS5 fırsatı',
        price: 18999,
        store: 'Amazon',
        category: 'Elektronik',
        link: 'https://amazon.com.tr',
        imageUrl: 'https://example.com/img.jpg',
        hotVotes: 10,
        coldVotes: 0,
        commentCount: 5,
        postedBy: 'user1',
        isEditorPick: false,
        createdAt: DateTime.now(),
      );

      final dealB = Deal(
        id: '2',
        title: 'Sony DualSense Şarj İstasyonu Konsol Aksesuarı',
        description: 'PlayStation için şarj ünitesi',
        price: 999,
        store: 'Amazon',
        category: 'Elektronik',
        link: 'https://amazon.com.tr',
        imageUrl: 'https://example.com/img.jpg',
        hotVotes: 5,
        coldVotes: 0,
        commentCount: 1,
        postedBy: 'user2',
        isEditorPick: false,
        createdAt: DateTime.now(),
      );

      final results = DealSearchEngine.searchDeals([dealB, dealA], 'PlayStation 5');
      // dealA matches both 'playstation' and '5' in title, so it must rank first
      expect(results.first.id, equals('1'));
    });
  });

  group('FAZ 2: FS-21 Message Model & Participants Contract Tests', () {
    test('Message model initializes and serializes participants correctly', () {
      final msg = Message(
        id: 'msg_123',
        conversationId: 'userA_userB',
        participants: ['userA', 'userB'],
        senderId: 'userA',
        senderName: 'Ali',
        senderImageUrl: 'https://example.com/a.jpg',
        receiverId: 'userB',
        receiverName: 'Veli',
        receiverImageUrl: 'https://example.com/b.jpg',
        text: 'Merhaba, bu fırsat hala geçerli mi?',
        createdAt: DateTime(2026, 10, 5, 20, 0),
      );

      final map = msg.toFirestore();
      expect(map['participants'], equals(['userA', 'userB']));
      expect(map['conversationId'], equals('userA_userB'));
      expect(map['senderId'], equals('userA'));
      expect(map['receiverId'], equals('userB'));
    });

    test('Message computeConversationId generates sorted deterministic ID', () {
      expect(Message.computeConversationId('userZ', 'userA'), equals('userA_userZ'));
      expect(Message.computeConversationId('userA', 'userZ'), equals('userA_userZ'));
    });

    test('Message copyWith preserves participants', () {
      final msg = Message(
        id: 'msg_1',
        senderId: 'userA',
        senderName: 'Ali',
        senderImageUrl: '',
        receiverId: 'userB',
        receiverName: 'Veli',
        receiverImageUrl: '',
        text: 'Test',
        createdAt: DateTime.now(),
        participants: ['userA', 'userB'],
      );

      final copied = msg.copyWith(isRead: true);
      expect(copied.participants, equals(['userA', 'userB']));
      expect(copied.isRead, isTrue);
    });
  });
}
