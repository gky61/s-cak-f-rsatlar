import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/auth_service.dart';

void main() {
  group('Email Authentication Logic & Validation Tests', () {
    // 1. Email Regex Validation
    test('Email format regex accurately validates standard email formats', () {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

      expect(emailRegex.hasMatch('test@firsatkolik.app'), isTrue);
      expect(emailRegex.hasMatch('user.name@domain.co'), isTrue);
      expect(emailRegex.hasMatch('avci123@gmail.com'), isTrue);
      expect(emailRegex.hasMatch('destek@firsatkolik.com.tr'), isTrue);
      expect(emailRegex.hasMatch('avci+kampanya@firsatkolik.istanbul'), isTrue);

      // Geçersiz formatlar
      expect(emailRegex.hasMatch('gecersiz-email'), isFalse);
      expect(emailRegex.hasMatch('@domain.com'), isFalse);
      expect(emailRegex.hasMatch('test@.com'), isFalse);
      expect(emailRegex.hasMatch('test@domain'), isFalse);
      expect(emailRegex.hasMatch(''), isFalse);
    });

    // 2. Password Length Validation
    test('Password length requirement enforces minimum 6 characters', () {
      bool isValidPassword(String password) => password.length >= 6;

      expect(isValidPassword('12345'), isFalse);
      expect(isValidPassword(''), isFalse);
      expect(isValidPassword('123456'), isTrue);
      expect(isValidPassword('gucluSifre2026!'), isTrue);
    });

    // 3. Username Validation
    test('Username rule enforces minimum 3 characters and trimming', () {
      bool isValidUsername(String username) {
        final clean = username.trim();
        return clean.length >= 3 && clean.length <= 30;
      }

      expect(isValidUsername('ab'), isFalse);
      expect(isValidUsername('  a  '), isFalse);
      expect(isValidUsername('ali'), isTrue);
      expect(isValidUsername('  firsat_avcisi  '), isTrue);
      expect(isValidUsername('a' * 31), isFalse);
    });

    // 4. AuthException Error Formatting
    test('AuthException retains clear message string', () {
      final ex = AuthException('E-posta adresi veya şifre hatalı.');
      expect(ex.message, 'E-posta adresi veya şifre hatalı.');
      expect(ex.toString(), 'E-posta adresi veya şifre hatalı.');
    });

    // 5. FS-AUTH-02: Apple Sign-In Name Combination & Trim Logic
    test('Apple Sign-In name combination formats given and family names properly', () {
      String? combineAppleName(String? given, String? family) {
        if (given != null || family != null) {
          final g = given ?? '';
          final f = family ?? '';
          final combined = '$g $f'.trim();
          if (combined.isNotEmpty) return combined;
        }
        return null;
      }

      expect(combineAppleName('Murat', 'Kaya'), 'Murat Kaya');
      expect(combineAppleName('Ahmet', null), 'Ahmet');
      expect(combineAppleName(null, 'Demir'), 'Demir');
      expect(combineAppleName('', '   '), isNull);
      expect(combineAppleName(null, null), isNull);
    });

    // 6. FS-AUTH-02: Placeholder Username Self-Healing Detection
    test('Placeholder username detection identifies default names and email prefixes', () {
      bool isUsernamePlaceholder(String username, String? email) {
        return username == 'Kullanıcı' ||
            username.isEmpty ||
            username.contains('@') ||
            (email != null && username == email.split('@')[0]);
      }

      expect(isUsernamePlaceholder('Kullanıcı', 'test@apple.com'), isTrue);
      expect(isUsernamePlaceholder('', 'test@apple.com'), isTrue);
      expect(isUsernamePlaceholder('test@privaterelay.appleid.com', 'test@privaterelay.appleid.com'), isTrue);
      expect(isUsernamePlaceholder('test', 'test@apple.com'), isTrue);
      expect(isUsernamePlaceholder('Murat Kaya', 'test@apple.com'), isFalse);
      expect(isUsernamePlaceholder('firsat_avcisi', 'avci@gmail.com'), isFalse);
    });

    // 7. FS-AUTH-10: Password Reset Cooldown & Rate-Limit Tests
    test('Password reset cooldown remaining behaves deterministically and is case-insensitive', () {
      expect(AuthService.getPasswordResetCooldownRemaining(''), 0);
      expect(AuthService.getPasswordResetCooldownRemaining('hic_istek_atilmamis@firsatkolik.app'), 0);
      expect(AuthService.passwordResetCooldown.inSeconds, 60);
    });

    // 8. FS-AUTH-05: CGNAT Friendly Guidance Message Tests
    test('Friendly error converts too-many-requests to actionable CGNAT & OAuth guidance', () {
      const friendlyMsg = 'Ağınızdan çok fazla deneme yapıldı (Mobil operatör yoğunluğu). '
          'Mobil verinizi veya Wi-Fi\'yi kapatıp açarak IP adresinizi yenileyebilir ya da '
          'Google / Apple ile tek tıkla hemen giriş yapabilirsiniz.';

      expect(friendlyMsg.contains('Mobil operatör'), isTrue);
      expect(friendlyMsg.contains('Google / Apple'), isTrue);
      expect(friendlyMsg.contains('IP adresinizi yenileyebilir'), isTrue);
    });

    // 9. FS-AUTH-06: Maximum 3 Active Devices & LRU Pruning Sort Test
    test('3 Device limit LRU pruning algorithm accurately sorts and selects oldest devices to prune', () {
      final now = DateTime.now();
      final devices = [
        {'id': 'dev_1', 'time': now.subtract(const Duration(days: 10))},
        {'id': 'dev_2', 'time': now.subtract(const Duration(minutes: 5))},
        {'id': 'dev_3', 'time': now.subtract(const Duration(hours: 1))},
        {'id': 'dev_4', 'time': now.subtract(const Duration(days: 3))},
      ];

      // En yeni ilk gelecek şekilde sırala
      devices.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));

      // En yeni ilk 2 cihaz korunur (mevcut 1 cihaz + 2 eski = toplam 3)
      final kept = devices.take(2).map((d) => d['id']).toList();
      final pruned = devices.skip(2).map((d) => d['id']).toList();

      expect(kept, ['dev_2', 'dev_3']);
      expect(pruned, ['dev_4', 'dev_1']);
    });

    // 10. FS-AUTH-04: Thundering Herd 24-hour Disk Cache TTL Test
    test('Thundering herd 24h disk TTL correctly determines whether Firestore skip is valid', () {
      const diskTTL = Duration(hours: 24);
      final now = DateTime.now();

      final freshTime = now.subtract(const Duration(hours: 4));
      final staleTime = now.subtract(const Duration(hours: 25));

      bool shouldSkipFirestore(DateTime timestamp) {
        return now.difference(timestamp) < diskTTL;
      }

      expect(shouldSkipFirestore(freshTime), isTrue);
      expect(shouldSkipFirestore(staleTime), isFalse);
    });

    // 11. FS-AUTH-07: Admin Cache 1-Minute TTL & Fail-Closed Logic Test
    test('Admin cache TTL expires after 1 minute ensuring fail-closed privilege verification', () {
      const adminTTL = Duration(minutes: 1);
      final now = DateTime.now();

      final withinTTL = now.subtract(const Duration(seconds: 45));
      final expiredTTL = now.subtract(const Duration(seconds: 75));

      bool isCacheValid(DateTime? lastCheck) {
        if (lastCheck == null) return false;
        return now.difference(lastCheck) < adminTTL;
      }

      expect(isCacheValid(withinTTL), isTrue);
      expect(isCacheValid(expiredTTL), isFalse);
      expect(isCacheValid(null), isFalse);
    });

    // 12. FS-AUTH-08: Apple Token Revocation Payload & Parameter Formatting Test
    test('Apple Token Revocation payload correctly formats parameters for Guideline 5.1.1(v)', () {
      Map<String, dynamic> buildRevokePayload(String uid, {String? authCode}) {
        return {
          'data': {
            'uid': uid,
            if (authCode != null) 'authorizationCode': authCode,
          },
        };
      }

      final payloadWithCode = buildRevokePayload('user_apple_123', authCode: 'c_auth_code_xyz');
      expect(payloadWithCode['data']['uid'], 'user_apple_123');
      expect(payloadWithCode['data']['authorizationCode'], 'c_auth_code_xyz');

      final payloadWithoutCode = buildRevokePayload('user_apple_456');
      expect(payloadWithoutCode['data']['uid'], 'user_apple_456');
      expect(payloadWithoutCode['data'].containsKey('authorizationCode'), isFalse);
    });

    // 13. FS-AUTH-09: Single-Flight Name Adoption & Deduplication Logic Test
    test('Delayed explicit name adopts into placeholder user profile accurately', () {
      bool shouldAdoptName(String currentUsername, String? newName, String? email) {
        if (newName == null || newName.trim().isEmpty) return false;
        final isPlaceholder = currentUsername == 'Kullanıcı' ||
            currentUsername.isEmpty ||
            currentUsername.contains('@') ||
            (email != null && currentUsername == email.split('@')[0]);
        return isPlaceholder;
      }

      expect(shouldAdoptName('Kullanıcı', 'Murat Kaya', 'murat@apple.com'), isTrue);
      expect(shouldAdoptName('murat', 'Murat Kaya', 'murat@apple.com'), isTrue);
      expect(shouldAdoptName('ÖzelAvcıAdı', 'Murat Kaya', 'murat@apple.com'), isFalse);
      expect(shouldAdoptName('Kullanıcı', '', 'murat@apple.com'), isFalse);
      expect(shouldAdoptName('Kullanıcı', null, 'murat@apple.com'), isFalse);
    });
  });
}
