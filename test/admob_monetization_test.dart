import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sicak_firsatlar/firebase_options.dart';
import 'package:sicak_firsatlar/services/ad_manager_service.dart';

void main() {
  group('AdMob Monetization & Platform Configuration Tests', () {
    test('1. DefaultFirebaseOptions delivers platform-distinct test ad units in dev/debug mode', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(DefaultFirebaseOptions.bannerAdUnitId, 'ca-app-pub-3940256099942544/6300978111');
        expect(DefaultFirebaseOptions.interstitialAdUnitId, 'ca-app-pub-3940256099942544/1033173712');
        expect(DefaultFirebaseOptions.nativeAdUnitId, 'ca-app-pub-3940256099942544/2247696110');
        expect(DefaultFirebaseOptions.rewardedAdUnitId, 'ca-app-pub-3940256099942544/5224354917');
        expect(DefaultFirebaseOptions.appOpenAdUnitId, 'ca-app-pub-3940256099942544/9257395921');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(DefaultFirebaseOptions.bannerAdUnitId, 'ca-app-pub-3940256099942544/2934735716');
        expect(DefaultFirebaseOptions.interstitialAdUnitId, 'ca-app-pub-3940256099942544/4411468910');
        expect(DefaultFirebaseOptions.nativeAdUnitId, 'ca-app-pub-3940256099942544/3986624511');
        expect(DefaultFirebaseOptions.rewardedAdUnitId, 'ca-app-pub-3940256099942544/1712485313');
        expect(DefaultFirebaseOptions.appOpenAdUnitId, 'ca-app-pub-3940256099942544/5575463023');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('2. android/app/build.gradle separates dev and prod AdMob App IDs via manifestPlaceholders', () {
      final buildGradle = File('android/app/build.gradle').readAsStringSync();
      expect(buildGradle.contains('manifestPlaceholders'), isTrue);
      expect(buildGradle.contains('ca-app-pub-3940256099942544~3347511713'), isTrue,
          reason: 'Dev flavor must use official Google Android sample App ID');
      expect(buildGradle.contains('ca-app-pub-6853997017739651~8861215767'), isTrue,
          reason: 'Prod flavor must use genuine FırsatKolik App ID');
    });

    test('3. android/app/src/main/AndroidManifest.xml uses \${admob_app_id} dynamic placeholder', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest.contains('android:value="\${admob_app_id}"'), isTrue,
          reason: 'AndroidManifest must use dynamic placeholder instead of hardcoded prod ID');
    });

    test('4. AdManagerService singleton, Kill-Switch, and Cooldown state logic works reliably', () {
      final adManager = AdManagerService.instance;
      expect(adManager, isNotNull);
      expect(adManager.isAdsEnabled, isTrue);

      const testUnitId = 'test_ad_unit_123';
      expect(adManager.canRequestAd(testUnitId), isTrue);

      // Simulate a failure to trigger cooldown
      adManager.recordAdFailure(
        testUnitId,
        LoadAdError(3, 'Google', 'No ad config', null),
      );

      // Immediately checking should block request due to 25s cooldown
      expect(adManager.canRequestAd(testUnitId), isFalse);

      // Reset on success
      adManager.recordAdSuccess(testUnitId);
      expect(adManager.canRequestAd(testUnitId), isTrue);

      // Kill Switch test
      adManager.isAdsEnabled = false;
      expect(adManager.canRequestAd(testUnitId), isFalse);
      adManager.isAdsEnabled = true;
    });

    test('5. ad_deal_card.dart does NOT use FittedBox with MediumRectangle scaling hack', () {
      final dealCardCode = File('lib/widgets/ad_deal_card.dart').readAsStringSync();
      final bannerWidgetCode = File('lib/widgets/ad_banner_widget.dart').readAsStringSync();

      expect(bannerWidgetCode.contains('FittedBox('), isFalse,
          reason: 'FittedBox scaling down AdMob banners is an AdMob policy violation');
      expect(dealCardCode.contains('FittedBox('), isFalse);
      expect(dealCardCode.contains('AdManagerService'), isTrue);
    });
  });
}
