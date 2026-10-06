import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FAZ 3: Bellek ve Ölçekleme Doğrulama Testleri', () {
    
    // =========================================================================
    // FS-24: 30'lu Chunk ve Sıralama Koruma Mantığı
    // =========================================================================
    test('FS-24: 30 elemanlı chunklama ve orijinal takip sırasını koruma', () {
      final followingIds = List.generate(75, (i) => 'user_$i');
      
      // 30'lu chunklara ayırma
      final chunks = <List<String>>[];
      for (var i = 0; i < followingIds.length; i += 30) {
        chunks.add(followingIds.sublist(
          i,
          (i + 30 > followingIds.length) ? followingIds.length : i + 30,
        ));
      }

      expect(chunks.length, 3);
      expect(chunks[0].length, 30);
      expect(chunks[1].length, 30);
      expect(chunks[2].length, 15);

      // Firestore whereIn 30 elemandan fazla alamaz
      for (final chunk in chunks) {
        expect(chunk.length <= 30, true);
      }

      // Reorder simülasyonu: Firestore sorguları asenkron dönebilir
      final unorderedUsers = [
        {'id': 'user_45'},
        {'id': 'user_0'},
        {'id': 'user_74'},
        {'id': 'user_10'},
      ];

      unorderedUsers.sort((a, b) {
        final indexA = followingIds.indexOf(a['id']!);
        final indexB = followingIds.indexOf(b['id']!);
        return indexA.compareTo(indexB);
      });

      expect(unorderedUsers.map((u) => u['id']).toList(), [
        'user_0',
        'user_10',
        'user_45',
        'user_74',
      ]);
    });

    // =========================================================================
    // FS-25: Dinamik FCM Keyword Topic Sanitizasyonu ve Eşleşme
    // =========================================================================
    test('FS-25: Kelime Radarı topic sanitizasyonu ve FCM standart uyumu', () {
      String sanitizeKeywordToTopic(String rawKeyword) {
        // Türkçe karakter ve normalize kelime temizliği
        var normalized = rawKeyword
            .toLowerCase()
            .replaceAll('ı', 'i')
            .replaceAll('ğ', 'g')
            .replaceAll('ü', 'u')
            .replaceAll('ş', 's')
            .replaceAll('ö', 'o')
            .replaceAll('ç', 'c');
        
        final cleanKw = normalized
            .replaceAll(RegExp(r'[^a-z0-9_-]'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
        return 'kw_$cleanKw';
      }

      // FCM Topic regex formatı: [a-zA-Z0-9-_.~%]+
      final fcmTopicRegex = RegExp(r'^[a-zA-Z0-9-_.~%]+$');

      final testCases = {
        'iPhone 15 Pro Max': 'kw_iphone_15_pro_max',
        'Kahve & Çay Makinesi': 'kw_kahve_cay_makinesi',
        'AirPods 3. Nesil!': 'kw_airpods_3_nesil',
        'dyson-v15': 'kw_dyson-v15',
        'lego_star_wars': 'kw_lego_star_wars',
        '___test___': 'kw_test',
      };

      testCases.forEach((input, expectedTopic) {
        final topic = sanitizeKeywordToTopic(input);
        expect(topic, expectedTopic);
        expect(fcmTopicRegex.hasMatch(topic), true,
            reason: '$topic geçerli bir FCM topic karakter seti içermeli');
      });
    });

    // =========================================================================
    // FS-26: typingStatus TTL ve 5 Saniye Tazelik Kontrolü
    // =========================================================================
    test('FS-26: typingStatus expireAt ve 5s staleness düşürme mantığı', () {
      final now = DateTime.now();
      final expireAt = now.add(const Duration(minutes: 10));

      // expireAt en az 9.9 dakika ileride olmalı
      final diffMinutes = expireAt.difference(now).inMinutes;
      expect(diffMinutes, 10);

      // getTypingStream staleness drop
      bool isTypingActive(DateTime updatedAt, bool isTyping) {
        final diffSeconds = DateTime.now().difference(updatedAt).inSeconds;
        if (diffSeconds > 5) return false;
        return isTyping;
      }

      // Taze yazıyor sinyali (2 saniye önce)
      expect(isTypingActive(DateTime.now().subtract(const Duration(seconds: 2)), true), true);

      // Bayatlamış yazıyor sinyali (6 saniye önce) -> anında false dönmeli
      expect(isTypingActive(DateTime.now().subtract(const Duration(seconds: 6)), true), false);
    });

    // =========================================================================
    // FS-27: AdMob Bounded KeepAlive LRU Havuzu Mantığı
    // =========================================================================
    test('FS-27: AdMob Bounded KeepAlive LRU havuzu azami 5 ad tutmalı', () {
      final activePool = <String>[];
      final revokedItems = <String>[];
      const maxConcurrent = 5;

      void grantKeepAlive(String id) {
        activePool.remove(id);
        activePool.add(id);
        if (activePool.length > maxConcurrent) {
          final oldest = activePool.removeAt(0);
          revokedItems.add(oldest);
        }
      }

      void touchKeepAlive(String id) {
        if (activePool.contains(id)) {
          activePool.remove(id);
          activePool.add(id);
        } else {
          grantKeepAlive(id);
        }
      }

      // 7 adet reklam sırayla havuza girer
      grantKeepAlive('ad_1');
      grantKeepAlive('ad_2');
      grantKeepAlive('ad_3');
      grantKeepAlive('ad_4');
      grantKeepAlive('ad_5');

      expect(activePool.length, 5);
      expect(activePool, ['ad_1', 'ad_2', 'ad_3', 'ad_4', 'ad_5']);
      expect(revokedItems.isEmpty, true);

      // 6. reklam geldiğinde en eski ad_1 düşürülmeli
      grantKeepAlive('ad_6');
      expect(activePool.length, 5);
      expect(activePool, ['ad_2', 'ad_3', 'ad_4', 'ad_5', 'ad_6']);
      expect(revokedItems, ['ad_1']);

      // 7. reklam geldiğinde ad_2 düşürülmeli
      grantKeepAlive('ad_7');
      expect(activePool.length, 5);
      expect(activePool, ['ad_3', 'ad_4', 'ad_5', 'ad_6', 'ad_7']);
      expect(revokedItems, ['ad_1', 'ad_2']);

      // Kullanıcı ad_3'e geri döndüğünde (touch), ad_3 en sona (MRU) taşınmalı
      touchKeepAlive('ad_3');
      expect(activePool, ['ad_4', 'ad_5', 'ad_6', 'ad_7', 'ad_3']);

      // Yeni ad_8 geldiğinde ad_4 düşürülmeli (ad_3 korundu!)
      grantKeepAlive('ad_8');
      expect(activePool, ['ad_5', 'ad_6', 'ad_7', 'ad_3', 'ad_8']);
      expect(revokedItems, ['ad_1', 'ad_2', 'ad_4']);
    });
  });
}
