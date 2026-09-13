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
      expect(DefaultFirebaseOptions.iosDev.appId, '1:560592268193:ios:be496ea2d9e55177d6f9e0');
      expect(DefaultFirebaseOptions.iosDev.messagingSenderId, '560592268193');
      expect(DefaultFirebaseOptions.iosDev.storageBucket, contains('firebasestorage.app'));
      expect(DefaultFirebaseOptions.iosDev.iosBundleId, 'com.firsatkolik.app');
      expect(DefaultFirebaseOptions.iosDev.iosClientId, isNotNull);
      expect(DefaultFirebaseOptions.iosDev.iosClientId, contains('560592268193'));
    });

    test('iosProd configuration has valid parameters', () {
      expect(DefaultFirebaseOptions.iosProd.projectId, 'firsatkolik-prod-e6eae');
      expect(DefaultFirebaseOptions.iosProd.apiKey, isNotEmpty);
      expect(DefaultFirebaseOptions.iosProd.appId, '1:228657473310:ios:5f779f3647ed4dd2380b0f');
      expect(DefaultFirebaseOptions.iosProd.messagingSenderId, '228657473310');
      expect(DefaultFirebaseOptions.iosProd.storageBucket, contains('firebasestorage.app'));
      expect(DefaultFirebaseOptions.iosProd.iosBundleId, 'com.firsatkolik.app');
      expect(DefaultFirebaseOptions.iosProd.iosClientId, isNotNull);
      expect(DefaultFirebaseOptions.iosProd.iosClientId, contains('228657473310'));
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

    test('ios/Runner/Info.plist contains all mandatory Apple Review, AdMob keys and genuine Google reversed client IDs', () {
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
      expect(infoPlist.contains('UIApplicationSceneManifest'), isFalse,
          reason: 'UIApplicationSceneManifest must NOT be present as experimental UIScene causes swipe-to-kill crash on iOS');
      expect(infoPlist.contains('com.googleusercontent.apps.228657473310-7dlhjuj25p2ov8o5274n3o3759h6gubs'), isTrue);
      expect(infoPlist.contains('com.googleusercontent.apps.560592268193-a70ituj4997v31non78gvno3f5tsked7'), isTrue);
    });

    test('AppDelegate.swift uses stable FlutterAppDelegate without experimental FlutterImplicitEngineDelegate', () {
      final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(appDelegate.contains('class AppDelegate: FlutterAppDelegate'), isTrue);
      expect(appDelegate.contains('FlutterImplicitEngineDelegate'), isFalse);
      expect(appDelegate.contains('GeneratedPluginRegistrant.register(with: self)'), isTrue);
    });

    test('GoogleService-Info.plist exists and contains valid iOS Google configuration', () {
      final plistFile = File('ios/Runner/GoogleService-Info.plist');
      expect(plistFile.existsSync(), isTrue);
      final content = plistFile.readAsStringSync();
      expect(content.contains('CLIENT_ID'), isTrue);
      expect(content.contains('REVERSED_CLIENT_ID'), isTrue);
      expect(content.contains('BUNDLE_ID'), isTrue);
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
