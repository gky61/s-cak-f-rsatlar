import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/firebase_options.dart';

void main() {
  group('iOS Platform Compatibility & Firebase Options Tests', () {
    test('iosDev configuration has valid parameters', () {
      expect(DefaultFirebaseOptions.iosDev.projectId, 'sicak-firsatlar-e6eae');
      expect(DefaultFirebaseOptions.iosDev.apiKey, isNotEmpty);
      expect(DefaultFirebaseOptions.iosDev.appId, contains(':ios:'));
      expect(DefaultFirebaseOptions.iosDev.messagingSenderId, '560592268193');
      expect(DefaultFirebaseOptions.iosDev.storageBucket, contains('firebasestorage.app'));
      expect(DefaultFirebaseOptions.iosDev.iosBundleId, 'com.sicakfirsatlar.sicakFirsatlar');
    });

    test('iosProd configuration has valid parameters', () {
      expect(DefaultFirebaseOptions.iosProd.projectId, 'firsatkolik-prod-e6eae');
      expect(DefaultFirebaseOptions.iosProd.apiKey, isNotEmpty);
      expect(DefaultFirebaseOptions.iosProd.appId, contains(':ios:'));
      expect(DefaultFirebaseOptions.iosProd.messagingSenderId, '228657473310');
      expect(DefaultFirebaseOptions.iosProd.storageBucket, contains('firebasestorage.app'));
      expect(DefaultFirebaseOptions.iosProd.iosBundleId, 'com.firsatkolik.app');
    });

    test('DefaultFirebaseOptions returns valid options without throwing UnsupportedError for iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final options = DefaultFirebaseOptions.currentPlatform;
        expect(options.projectId, isNotEmpty);
        expect(options.apiKey, isNotEmpty);
        expect(options.appId, contains(':ios:'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('bannerAdUnitId returns distinct platform test IDs for iOS and Android in debug/dev', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final iosBannerId = DefaultFirebaseOptions.bannerAdUnitId;
        expect(iosBannerId, 'ca-app-pub-3940256099942544/2934735716');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final androidBannerId = DefaultFirebaseOptions.bannerAdUnitId;
        expect(androidBannerId, 'ca-app-pub-3940256099942544/6300978111');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('ios/Runner/Info.plist contains all mandatory Apple Review and AdMob keys', () {
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(infoPlist.contains('GADApplicationIdentifier'), isTrue);
      expect(infoPlist.contains('SKAdNetworkItems'), isTrue);
      expect(infoPlist.contains('LSApplicationQueriesSchemes'), isTrue);
      expect(infoPlist.contains('hbapp'), isTrue);
      expect(infoPlist.contains('itms-apps'), isTrue);
      expect(infoPlist.contains('FlutterDeepLinkingEnabled'), isTrue);
      expect(infoPlist.contains('NSUserTrackingUsageDescription'), isTrue);
      expect(infoPlist.contains('NSPhotoLibraryUsageDescription'), isTrue);
      expect(infoPlist.contains('ITSAppUsesNonExemptEncryption'), isTrue);
      expect(infoPlist.contains('UIApplicationSceneManifest'), isTrue);
    });

    test('ios/Runner/Runner.entitlements contains Sign in with Apple, APNs and Associated Domains', () {
      final entitlements = File('ios/Runner/Runner.entitlements').readAsStringSync();
      expect(entitlements.contains('com.apple.developer.applesignin'), isTrue);
      expect(entitlements.contains('aps-environment'), isTrue);
      expect(entitlements.contains('com.apple.developer.associated-domains'), isTrue);
      expect(entitlements.contains('applinks:firsatkolik.app'), isTrue);
    });

    test('apple-app-site-association file is valid JSON with applinks', () {
      final aasaFile = File('web/.well-known/apple-app-site-association');
      expect(aasaFile.existsSync(), isTrue);
      final jsonContent = jsonDecode(aasaFile.readAsStringSync()) as Map<String, dynamic>;
      expect(jsonContent.containsKey('applinks'), isTrue);
      final applinks = jsonContent['applinks'] as Map<String, dynamic>;
      expect(applinks.containsKey('details'), isTrue);
    });
  });
}
