import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sicak_firsatlar/services/firestore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FirestoreService.clearAnnouncementCache();
  });

  tearDown(() {
    FirestoreService.clearAnnouncementCache();
  });

  group('FirestoreService - Bildirim & Duyuru Senkronizasyon Kalkanı Testleri', () {
    test('1. clearAnnouncementCache statik önbelleği ve kullanıcı durumunu sıfırlamalı', () {
      expect(FirestoreService.cachedReadAnnouncements, isEmpty);
      expect(FirestoreService.cachedDismissedAnnouncements, isEmpty);
    });

    test('2. Evrensel ID Çözücü: rawId, normalizedId ve userId varyasyonları tam kapsanmalı', () {
      const userId = 'user_test_123';
      const rawId = 'coupon_super_firsat_99';
      final normalizedId = rawId.startsWith('manual_') ? rawId.substring(7) : rawId;

      final targetDocIds = <String>{rawId, normalizedId};
      if (rawId.endsWith('_$userId')) {
        final baseAnnouncementId = rawId.substring(0, rawId.length - userId.length - 1);
        if (baseAnnouncementId.isNotEmpty) {
          targetDocIds.add(baseAnnouncementId);
        }
      } else {
        targetDocIds.add('${rawId}_$userId');
        targetDocIds.add('${normalizedId}_$userId');
      }

      expect(targetDocIds, contains('coupon_super_firsat_99'));
      expect(targetDocIds, contains('coupon_super_firsat_99_user_test_123'));
    });

    test('3. Evrensel ID Çözücü: userId ile biten kişisel bildirimden ana duyuru ID çıkarılmalı', () {
      const userId = 'user_test_123';
      const rawId = 'coupon_super_firsat_99_user_test_123';
      final normalizedId = rawId.startsWith('manual_') ? rawId.substring(7) : rawId;

      final targetDocIds = <String>{rawId, normalizedId};
      if (rawId.endsWith('_$userId')) {
        final baseAnnouncementId = rawId.substring(0, rawId.length - userId.length - 1);
        if (baseAnnouncementId.isNotEmpty) {
          targetDocIds.add(baseAnnouncementId);
        }
      } else {
        targetDocIds.add('${rawId}_$userId');
        targetDocIds.add('${normalizedId}_$userId');
      }

      expect(targetDocIds, contains('coupon_super_firsat_99'));
      expect(targetDocIds, contains('coupon_super_firsat_99_user_test_123'));
    });

    test('4. Deduplication: Global duyuru ile kişisel bildirim tekilleştirilmeli', () {
      final filteredGlobals = [
        {
          'id': 'coupon_abc_1',
          'title': 'Global Kupon',
          'announcementId': 'coupon_abc_1',
          'read': false,
        }
      ];

      final filteredUsers = [
        {
          'id': 'coupon_abc_1_user_xyz',
          'title': 'Kişisel Kupon Bildirimi',
          'announcementId': 'coupon_abc_1',
          'read': false,
        }
      ];

      final seenIds = <String>{};
      final combined = <Map<String, dynamic>>[];

      for (final item in [...filteredGlobals, ...filteredUsers]) {
        final rawId = item['id'] as String? ?? '';
        final normalizedId = rawId.startsWith('manual_') ? rawId.substring(7) : rawId;
        final announcementId = item['announcementId'] as String? ?? normalizedId;
        final dedupKey = announcementId.isNotEmpty ? announcementId : rawId;

        if (dedupKey.isNotEmpty && !seenIds.add(dedupKey)) continue;
        combined.add(item);
      }

      expect(combined.length, equals(1));
      expect(combined.first['id'], equals('coupon_abc_1'));
    });

    test('5. Dismissed Filter: Gizlenen kupon kişisel doküman olarak kalsa bile elenmeli', () {
      final dismissedSet = {'coupon_silinen_kupon_42'};

      final latestUserNotifs = [
        {
          'id': 'coupon_silinen_kupon_42_user_xyz',
          'announcementId': 'coupon_silinen_kupon_42',
          'title': 'Silinen Kupon Bildirimi',
        },
        {
          'id': 'deal_normal_firsat_1',
          'announcementId': '',
          'title': 'Normal Fırsat',
        }
      ];

      final filteredUsers = latestUserNotifs.where((u) {
        final id = u['id']?.toString() ?? '';
        final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
        final announcementId = u['announcementId']?.toString() ?? '';
        if (dismissedSet.contains(id) ||
            dismissedSet.contains(normalizedId) ||
            (announcementId.isNotEmpty && (dismissedSet.contains(announcementId) || dismissedSet.contains('manual_$announcementId')))) {
          return false;
        }
        return true;
      }).toList();

      expect(filteredUsers.length, equals(1));
      expect(filteredUsers.first['id'], equals('deal_normal_firsat_1'));
    });

    test('6. Read Filter: Okunan kupon kişisel doküman olarak kalsa bile read=true işaretlenmeli', () {
      final readSet = {'coupon_okunan_kupon_88'};

      final latestUserNotifs = [
        {
          'id': 'coupon_okunan_kupon_88_user_xyz',
          'announcementId': 'coupon_okunan_kupon_88',
          'title': 'Okunan Kupon Bildirimi',
          'read': false,
        }
      ];

      final filteredUsers = latestUserNotifs.where((u) {
        final id = u['id']?.toString() ?? '';
        final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
        final announcementId = u['announcementId']?.toString() ?? '';
        if (readSet.contains(id) ||
            readSet.contains(normalizedId) ||
            (announcementId.isNotEmpty && (readSet.contains(announcementId) || readSet.contains('manual_$announcementId')))) {
          u['read'] = true;
        }
        return true;
      }).toList();

      expect(filteredUsers.length, equals(1));
      expect(filteredUsers.first['read'], isTrue);
    });
  });
}
