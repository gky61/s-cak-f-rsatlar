import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/firebase_options.dart';

void main() {
  group('iOS Authentication Architecture Tests', () {
    test('iosProd and iosDev have valid, genuine iOS OAuth Client IDs', () {
      expect(DefaultFirebaseOptions.iosProd.iosClientId, isNotNull);
      expect(DefaultFirebaseOptions.iosProd.iosClientId,
          '228657473310-7dlhjuj25p2ov8o5274n3o3759h6gubs.apps.googleusercontent.com');

      expect(DefaultFirebaseOptions.iosDev.iosClientId, isNotNull);
      expect(DefaultFirebaseOptions.iosDev.iosClientId,
          '560592268193-a70ituj4997v31non78gvno3f5tsked7.apps.googleusercontent.com');
    });

    test('Cryptographic raw nonce generation produces 32-character secure random string', () {
      const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
      final random = Random.secure();
      final rawNonce = List.generate(32, (_) => charset[random.nextInt(charset.length)]).join();

      expect(rawNonce.length, 32);
      expect(RegExp(r'^[0-9A-Za-z\-._]+$').hasMatch(rawNonce), isTrue);

      final digest = sha256.convert(utf8.encode(rawNonce)).toString();
      expect(digest.length, 64); // SHA-256 hex string is 64 characters
    });

    test('DefaultFirebaseOptions.currentPlatform returns iOS options with iosClientId when platform is iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final options = DefaultFirebaseOptions.currentPlatform;
        expect(options.iosClientId, isNotNull);
        expect(options.iosClientId, contains('apps.googleusercontent.com'));
        expect(options.iosBundleId, 'com.firsatkolik.app');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
