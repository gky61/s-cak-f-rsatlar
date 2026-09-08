import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/affiliate/affiliate_service.dart';
import 'package:sicak_firsatlar/services/affiliate/adapters/hepsiburada_affiliate_adapter.dart';
import 'package:sicak_firsatlar/services/affiliate/adapters/teknosa_affiliate_adapter.dart';

void main() {
  group('StoreRedirectService & Hybrid Redirection Tests', () {
    const hbOrganic = 'https://www.hepsiburada.com/altinyildiz-classics-erkek-100-pamuk-v-yaka-lacivert-slim-fit-dar-kesim-tisort-p-HBCV00004RJ9GF';
    const hbAffiliate = 'https://7t4g.adj.st/product?sku=HBCV00004RJ9GF&adj_t=10zuiki3_y4q2fze&adj_adgroup=muratcan%20gokyokus&adj_fallback=https%3A%2F%2Fwww.hepsiburada.com%2Faltinyildiz-classics-erkek-100-pamuk-v-yaka-lacivert-slim-fit-dar-kesim-tisort-p-HBCV00004RJ9GF';

    const teknosaOrganic = 'https://www.teknosa.com/apple-iphone-13-128gb-yildiz-isigi-cep-telefonu-p-125077975';
    const teknosaAffiliate = 'https://rdr.btrck.com/link/68e2f07dc627685dc4224c6e?url=https%3A%2F%2Fwww.teknosa.com%2Fapple-iphone-13-128gb-yildiz-isigi-cep-telefonu-p-125077975&source=960eb24f-ef07-4251-87a3-5cbe71987dbe';

    tearDown(() {
      // Testler sonrası şalterleri varsayılan açık duruma getir
      AffiliateService.setStoreEnabled('hepsiburada', true);
      AffiliateService.setStoreEnabled('teknosa', true);
    });

    test('Kill-Switch OFF: Hepsiburada şalteri kapalıyken affiliate link doğrudan organik linke unwrap edilmelidir', () {
      AffiliateService.setStoreEnabled('hepsiburada', false);

      final adapter = AffiliateService.getAdapter(hbAffiliate);
      expect(adapter, isNotNull);
      expect(adapter!.isEnabled, isFalse);

      final unwrapResult = adapter.convert(Uri.parse(hbAffiliate));
      expect(unwrapResult, startsWith('https://www.hepsiburada.com/'));
      expect(unwrapResult.contains('7t4g.adj.st'), isFalse);
      expect(unwrapResult.contains('adjust_tracker'), isFalse);
    });

    test('Kill-Switch OFF: Teknosa şalteri kapalıyken affiliate link doğrudan organik linke unwrap edilmelidir', () {
      AffiliateService.setStoreEnabled('teknosa', false);

      final adapter = AffiliateService.getAdapter(teknosaAffiliate);
      expect(adapter, isNotNull);
      expect(adapter!.isEnabled, isFalse);

      final unwrapResult = adapter.convert(Uri.parse(teknosaAffiliate));
      expect(unwrapResult, startsWith('https://www.teknosa.com/'));
      expect(unwrapResult.contains('rdr.btrck.com'), isFalse);
      expect(unwrapResult.contains('btrck'), isFalse);
    });

    test('Kill-Switch ON: Hepsiburada şalteri açıkken affiliate adaptörü aktiftir ve hibrit akışa uygundur', () {
      AffiliateService.setStoreEnabled('hepsiburada', true);

      final adapter = AffiliateService.getAdapter(hbOrganic);
      expect(adapter, isNotNull);
      expect(adapter!.isEnabled, isTrue);

      final affiliateUrl = adapter.convert(Uri.parse(hbOrganic));
      expect(affiliateUrl, startsWith('https://7t4g.adj.st/'));
      expect(affiliateUrl.contains('adj_t=10zuiki3_y4q2fze'), isTrue);
      expect(affiliateUrl.contains('adj_adgroup=muratcan%20gokyokus'), isTrue);
    });

    test('Kill-Switch ON: Teknosa şalteri açıkken affiliate adaptörü aktiftir ve hibrit akışa uygundur', () {
      AffiliateService.setStoreEnabled('teknosa', true);

      final adapter = AffiliateService.getAdapter(teknosaOrganic);
      expect(adapter, isNotNull);
      expect(adapter!.isEnabled, isTrue);

      final affiliateUrl = adapter.convert(Uri.parse(teknosaOrganic));
      expect(affiliateUrl, startsWith('https://rdr.btrck.com/'));
      expect(affiliateUrl.contains('source='), isTrue);
    });

    test('Hepsiburada buildNativeAppUrl doğrudan hbapp:// şeması ve Adjust parametrelerini üretmelidir', () {
      final adapter = AffiliateService.getAdapter(hbOrganic) as HepsiburadaAffiliateAdapter;
      final nativeUrl = adapter.buildNativeAppUrl(Uri.parse(hbOrganic));

      expect(nativeUrl, isNotNull);
      expect(nativeUrl!, startsWith('hbapp://product'));
      final parsed = Uri.parse(nativeUrl);
      expect(parsed.queryParameters['sku'], equals('HBCV00004RJ9GF'));
      expect(parsed.queryParameters['adjust_tracker'], equals('10zuiki3_y4q2fze'));
      expect(parsed.queryParameters['adj_adgroup'], equals('muratcan gokyokus'));
    });

    test('Teknosa buildNativeAppUrl doğrudan teknosa.com App Link ve utm_campaign üretmelidir', () {
      final adapter = AffiliateService.getAdapter(teknosaOrganic) as TeknosaAffiliateAdapter;
      final nativeUrl = adapter.buildNativeAppUrl(Uri.parse(teknosaOrganic));

      expect(nativeUrl, startsWith('https://www.teknosa.com/'));
      expect(nativeUrl.contains('utm_source=social_affiliate'), isTrue);
      expect(nativeUrl.contains('utm_medium=paylaskazan'), isTrue);
      expect(nativeUrl.contains('utm_campaign=906bd201-92dc-4898-914a-10309b2cd576'), isTrue);
    });

    test('Desteklenmeyen genel mağazalarda adaptör null olmalı ve organik akış devam etmelidir', () {
      const a101Url = 'https://www.a101.com.tr/elektronik/akilli-telefon/';
      final adapter = AffiliateService.getAdapter(a101Url);
      expect(adapter, isNull);
    });
  });
}
