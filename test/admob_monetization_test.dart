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
        expect(DefaultFirebaseOptions.nativeAdUnitId, 'ca-app-pub-3940256099942544/2247696110');
        expect(DefaultFirebaseOptions.rewardedAdUnitId, 'ca-app-pub-3940256099942544/5224354917');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(DefaultFirebaseOptions.bannerAdUnitId, 'ca-app-pub-3940256099942544/2934735716');
        expect(DefaultFirebaseOptions.nativeAdUnitId, 'ca-app-pub-3940256099942544/3986624511');
        expect(DefaultFirebaseOptions.rewardedAdUnitId, 'ca-app-pub-3940256099942544/1712485313');
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

    test('6. Faz 3.3: AdNativeWidget exists, wires onPaidEvent telemetry and uses NativeTemplateStyle', () {
      final nativeWidgetFile = File('lib/widgets/ad_native_widget.dart');
      expect(nativeWidgetFile.existsSync(), isTrue);

      final code = nativeWidgetFile.readAsStringSync();
      expect(code.contains('NativeTemplateStyle('), isTrue,
          reason: 'Must use Google Mobile Ads official NativeTemplateStyle');
      expect(code.contains('TemplateType.small'), isTrue,
          reason: 'Horizontal ListView must use TemplateType.small');
      expect(code.contains('TemplateType.medium'), isTrue,
          reason: 'Vertical GridView must use TemplateType.medium');
      expect(code.contains('onPaidEvent:'), isTrue,
          reason: 'Must wire onPaidEvent telemetry for ROAS tracking');
      expect(code.contains('adManager.recordAdSuccess'), isTrue);
      expect(code.contains('adManager.recordAdFailure'), isTrue);
    });

    test('7. Faz 3.3: ad_deal_card.dart delegates stream ads to AdNativeWidget and nativeAdUnitId', () {
      final dealCardCode = File('lib/widgets/ad_deal_card.dart').readAsStringSync();
      expect(dealCardCode.contains('AdNativeWidget('), isTrue);
      expect(dealCardCode.contains('DefaultFirebaseOptions.nativeAdUnitId'), isTrue);
      expect(dealCardCode.contains('AdBannerWidget'), isFalse,
          reason: 'Old AdBannerWidget must be completely replaced by AdNativeWidget in deal stream');
    });

    test('8. Faz 3.3: AdManagerService and home_screen.dart support dynamic nativeGridInterval', () {
      final adManager = AdManagerService.instance;
      expect(adManager.nativeGridInterval, 6);

      final homeScreenCode = File('lib/screens/home_screen.dart').readAsStringSync();
      expect(homeScreenCode.contains('AdManagerService.instance.nativeGridInterval'), isTrue,
          reason: 'home_screen.dart must read dynamic grid interval from AdManagerService');
    });

    test('9. Faz 3.3: AdManagerService supports nativeCouponsEnabled and nativeCouponsInterval', () {
      final adManager = AdManagerService.instance;
      expect(adManager.nativeCouponsEnabled, isTrue);
      expect(adManager.nativeCouponsInterval, 5);
    });

    test('10. Faz 3.3: kuponlar_page.dart injects Native Ads every 5 items (after 4 coupons)', () {
      final kuponlarCode = File('lib/screens/kuponlar_page.dart').readAsStringSync();
      expect(kuponlarCode.contains('AdDealCard('), isTrue,
          reason: 'kuponlar_page.dart must inject AdDealCard into the stream');
      expect(kuponlarCode.contains("placement: 'kuponlar'"), isTrue,
          reason: 'kuponlar_page.dart must specify kuponlar placement for telemetry and fallback');
      expect(kuponlarCode.contains('nativeCouponsEnabled'), isTrue);
      expect(kuponlarCode.contains('nativeCouponsInterval'), isTrue);
      expect(kuponlarCode.contains('itemIndex % blockSize == couponsPerAd'), isTrue,
          reason: 'Must inject ad on the 5th item (after 4 coupons) consistently');
    });

    test('11. Faz 3.3: AdManagerService supports nativeAktuelEnabled and nativeAktuelInterval', () {
      final adManager = AdManagerService.instance;
      expect(adManager.nativeAktuelEnabled, isTrue);
      expect(adManager.nativeAktuelInterval, 6);
    });

    test('12. Faz 3.3: katalog_listesi_page.dart injects horizontal Native Ads after every 6 catalogs in 2-column grid', () {
      final katalogCode = File('lib/screens/katalog_listesi_page.dart').readAsStringSync();
      expect(katalogCode.contains('AdDealCard('), isTrue,
          reason: 'katalog_listesi_page.dart must inject AdDealCard into the grid stream');
      expect(katalogCode.contains("placement: 'aktuel'"), isTrue,
          reason: 'katalog_listesi_page.dart must specify aktuel placement for telemetry and fallback');
      expect(katalogCode.contains('nativeAktuelEnabled'), isTrue);
      expect(katalogCode.contains('nativeAktuelInterval'), isTrue);
      expect(katalogCode.contains('CardViewMode.horizontal'), isTrue,
          reason: 'Must render full-width horizontal card across the 2-column grid');
      expect(katalogCode.contains('chunkCatalogs.length == chunkSize'), isTrue,
          reason: 'Must inject ad banner only after complete chunk of 6 brochures (3 full rows)');
    });

    test('13. Faz 3.3: NativeAdOptions configured and unclipped 126 framing applied in ad_native_widget', () {
      final nativeWidgetCode = File('lib/widgets/ad_native_widget.dart').readAsStringSync();
      expect(nativeWidgetCode.contains('NativeAdOptions('), isTrue,
          reason: 'Must supply NativeAdOptions to prevent media & video constraints mismatch');
      expect(nativeWidgetCode.contains('mediaAspectRatio: MediaAspectRatio.landscape'), isTrue);
      expect(nativeWidgetCode.contains('height: 126'), isTrue,
          reason: 'Must maintain unclipped 126 framing for platform views');
      expect(nativeWidgetCode.contains('clipBehavior: Clip.antiAlias'), isTrue,
          reason: 'Must use native container clipBehavior instead of invasive nested ClipRRect');
    });

    test('14. Faz 3.3: iOS enterprise FLTNativeAdFactory architecture permanently eliminates validator issues', () {
      final nativeWidgetCode = File('lib/widgets/ad_native_widget.dart').readAsStringSync();
      expect(nativeWidgetCode.contains("'firsatkolik_native_ad_factory'"), isTrue,
          reason: 'ad_native_widget must route iOS native ads to custom FLTNativeAdFactory');

      final appDelegateCode = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(appDelegateCode.contains('FirsatKolikNativeAdFactory'), isTrue,
          reason: 'AppDelegate.swift must implement FirsatKolikNativeAdFactory');
      expect(appDelegateCode.contains('FLTGoogleMobileAdsPlugin.registerNativeAdFactory'), isTrue,
          reason: 'AppDelegate.swift must register firsatkolik_native_ad_factory');
      expect(appDelegateCode.contains('mediaContainer.widthAnchor.constraint(equalToConstant: 120)'), isTrue,
          reason: 'Media container must strictly enforce 120x120pt to satisfy video validator');

      final bridgingHeaderCode = File('ios/Runner/Runner-Bridging-Header.h').readAsStringSync();
      expect(bridgingHeaderCode.contains('FLTGoogleMobileAdsPlugin.h'), isTrue,
          reason: 'Runner-Bridging-Header.h must expose FLTGoogleMobileAdsPlugin to Swift');
    });

    test('15. Faz 3.3: NativeAd cold-start concurrency lock, keep-alive and scroll preservation', () {
      final nativeWidgetCode = File('lib/widgets/ad_native_widget.dart').readAsStringSync();
      expect(nativeWidgetCode.contains('AutomaticKeepAliveClientMixin'), isTrue,
          reason: '_AdNativeWidgetState must mix in AutomaticKeepAliveClientMixin');
      expect(nativeWidgetCode.contains('bool _isLoading = false;'), isTrue,
          reason: 'Must maintain atomic _isLoading guard against concurrent dual load calls');
      expect(nativeWidgetCode.contains('if (_isLoading || _isAdLoaded || !mounted)'), isTrue,
          reason: '_loadAd must reject duplicate in-flight load requests');
      expect(nativeWidgetCode.contains('didUpdateWidget(AdNativeWidget oldWidget)'), isTrue,
          reason: 'Must implement didUpdateWidget to handle viewMode or adUnitId switches');
      expect(nativeWidgetCode.contains('super.build(context);'), isTrue,
          reason: 'build method must invoke super.build(context) for KeepAlive');

      final homeScreenCode = File('lib/screens/home_screen.dart').readAsStringSync();
      expect(homeScreenCode.contains('addAutomaticKeepAlives: true'), isTrue,
          reason: 'home_screen.dart ListView.builder must enable addAutomaticKeepAlives for ad preservation');
    });

    test('16. Faz 3.4: AdManagerService supports nativePopular and nativeFollowedCategories settings', () {
      final adManager = AdManagerService.instance;
      expect(adManager.nativePopularEnabled, isTrue);
      expect(adManager.nativePopularInterval, equals(6));
      expect(adManager.nativeFollowedCategoriesEnabled, isTrue);
      expect(adManager.nativeFollowedCategoriesInterval, equals(6));

      // Test field mutation and notifyListeners
      bool notified = false;
      void listener() => notified = true;
      adManager.addListener(listener);

      adManager.nativePopularEnabled = false;
      adManager.nativeFollowedCategoriesEnabled = false;
      adManager.nativePopularInterval = 8;
      adManager.nativeFollowedCategoriesInterval = 7;
      adManager.notifyListeners();

      expect(notified, isTrue);
      expect(adManager.nativePopularEnabled, isFalse);
      expect(adManager.nativeFollowedCategoriesEnabled, isFalse);
      expect(adManager.nativePopularInterval, equals(8));
      expect(adManager.nativeFollowedCategoriesInterval, equals(7));

      // Revert to defaults
      adManager.nativePopularEnabled = true;
      adManager.nativeFollowedCategoriesEnabled = true;
      adManager.nativePopularInterval = 6;
      adManager.nativeFollowedCategoriesInterval = 6;
      adManager.notifyListeners();
      adManager.removeListener(listener);
    });

    test('17. Faz 3.4: popular_deals_screen.dart injects horizontal Native Ads into 2-column grid and list view', () {
      final popularCode = File('lib/screens/popular_deals_screen.dart').readAsStringSync();
      expect(popularCode.contains("import '../widgets/ad_deal_card.dart';"), isTrue,
          reason: 'Must import AdDealCard');
      expect(popularCode.contains("import '../services/ad_manager_service.dart';"), isTrue,
          reason: 'Must import AdManagerService');
      expect(popularCode.contains("_buildGridWithHorizontalAdsSlivers"), isTrue,
          reason: 'Must use chunked 2-column SliverGrid to avoid single-cell FittedBox scale down');
      expect(popularCode.contains("placement: 'popular'"), isTrue,
          reason: 'Must route placement to popular');
      expect(popularCode.contains("ListenableBuilder"), isTrue,
          reason: 'Must listen to AdManagerService for live remote Firestore updates');
    });

    test('18. Faz 3.4: favorites_screen.dart injects Native Ads into Favori Kategorilerim while guaranteeing 100% ad-free isolation for Kaydettiklerim', () {
      final favoritesCode = File('lib/screens/favorites_screen.dart').readAsStringSync();
      expect(favoritesCode.contains("import '../widgets/ad_deal_card.dart';"), isTrue,
          reason: 'Must import AdDealCard');
      expect(favoritesCode.contains("import '../services/ad_manager_service.dart';"), isTrue,
          reason: 'Must import AdManagerService');
      expect(favoritesCode.contains("_buildFollowedCategoriesDealGrid"), isTrue,
          reason: 'Must have dedicated grid builder with AdMob support for Tab 2');
      expect(favoritesCode.contains("placement: 'favorite_categories'"), isTrue,
          reason: 'Must tag ad impressions as favorite_categories placement');
      
      // CRITICAL FAIR-PLAY CHECK: Tab 1 ("Kaydettiklerim") must remain 100% ad-free!
      expect(favoritesCode.contains("_buildDealGrid(displayedDeals, isDark, _myFavoritesScrollController)"), isTrue,
          reason: 'Tab 1 (Kaydettiklerim) MUST use clean _buildDealGrid without any ads to protect high-intent affiliate conversions');
    });

    test('19. Faz 3.5: UMP Consent & ATT UI Orchestration prevents collision with Tutorial', () async {
      final adManager = AdManagerService.instance;
      expect(adManager.isConsentFlowCompleted, isFalse);

      // Verify markConsentFlowCompleted logic
      adManager.markConsentFlowCompleted();
      expect(adManager.isConsentFlowCompleted, isTrue);

      // Verify waitForConsentFlow returns immediately once completed
      await expectLater(adManager.waitForConsentFlow(timeout: const Duration(milliseconds: 100)), completes);

      // Verify main.dart wires markConsentFlowCompleted
      final mainCode = File('lib/main.dart').readAsStringSync();
      expect(mainCode.contains('AdManagerService.instance.markConsentFlowCompleted()'), isTrue,
          reason: 'main.dart must call markConsentFlowCompleted when UMP completes or dismisses');

      // Verify home_screen.dart waits for consent before starting tutorial
      final homeScreenCode = File('lib/screens/home_screen.dart').readAsStringSync();
      expect(homeScreenCode.contains('await AdManagerService.instance.waitForConsentFlow()'), isTrue,
          reason: 'home_screen.dart must await waitForConsentFlow before triggering tutorial');

      // Verify ios/Runner/Info.plist has Apple-compliant ATT description
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(infoPlist.contains('NSUserTrackingUsageDescription'), isTrue);
      expect(infoPlist.contains('Size özel indirim ve fırsat bildirimleri'), isFalse,
          reason: 'Must not confuse notifications with tracking permission in ATT description');
      expect(infoPlist.contains('İlginizi çeken fırsat ve indirimleri size özel sunabilmek'), isTrue);
    });
  });
}
