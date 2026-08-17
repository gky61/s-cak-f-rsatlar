import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/utils/store_asset_helper.dart';

void main() {
  group('StoreAssetHelper Tests', () {
    test('Tüm mağaza isimleri ve kodları doğru asset yolunu vermeli', () {
      // ŞOK varyasyonları
      expect(StoreAssetHelper.getStoreAsset('ŞOK'), 'assets/sok.webp');
      expect(StoreAssetHelper.getStoreAsset('Şok'), 'assets/sok.webp');
      expect(StoreAssetHelper.getStoreAsset('sok'), 'assets/sok.webp');
      expect(StoreAssetHelper.getStoreAsset('Şok Market'), 'assets/sok.webp');

      // Bizim Toptan varyasyonları
      expect(StoreAssetHelper.getStoreAsset('Bizim Toptan'), 'assets/bizim.webp');
      expect(StoreAssetHelper.getStoreAsset('Bizim'), 'assets/bizim.webp');
      expect(StoreAssetHelper.getStoreAsset('bizim'), 'assets/bizim.webp');

      // Çağrı Hipermarket varyasyonları
      expect(StoreAssetHelper.getStoreAsset('Çağrı Hipermarket'), 'assets/cagri.webp');
      expect(StoreAssetHelper.getStoreAsset('Çağrı'), 'assets/cagri.webp');
      expect(StoreAssetHelper.getStoreAsset('cagri'), 'assets/cagri.webp');

      // Çetinkaya varyasyonları
      expect(StoreAssetHelper.getStoreAsset('Çetinkaya'), 'assets/cetinkaya.webp');
      expect(StoreAssetHelper.getStoreAsset('cetinkaya'), 'assets/cetinkaya.webp');

      // BİM & A-101
      expect(StoreAssetHelper.getStoreAsset('BİM'), 'assets/bim.webp');
      expect(StoreAssetHelper.getStoreAsset('Bim'), 'assets/bim.webp');
      expect(StoreAssetHelper.getStoreAsset('bim'), 'assets/bim.webp');
      expect(StoreAssetHelper.getStoreAsset('A-101'), 'assets/a101.webp');
      expect(StoreAssetHelper.getStoreAsset('A101'), 'assets/a101.webp');
      expect(StoreAssetHelper.getStoreAsset('a101'), 'assets/a101.webp');

      // Kooperatif Market
      expect(StoreAssetHelper.getStoreAsset('Kooperatif Market'), 'assets/kooperatif.webp');
      expect(StoreAssetHelper.getStoreAsset('Tarım Kredi Kooperatif'), 'assets/kooperatif.webp');
      expect(StoreAssetHelper.getStoreAsset('kooperatifmarket'), 'assets/kooperatif.webp');

      // Hakmar & Hakmar Express
      expect(StoreAssetHelper.getStoreAsset('Hakmar'), 'assets/hakmar.webp');
      expect(StoreAssetHelper.getStoreAsset('Hakmar Express'), 'assets/hakmar-express.webp');
      expect(StoreAssetHelper.getStoreAsset('hakmar-express'), 'assets/hakmar-express.webp');

      // Vatan Bilgisayar
      expect(StoreAssetHelper.getStoreAsset('Vatan Bilgisayar'), 'assets/vatan.webp');
      expect(StoreAssetHelper.getStoreAsset('Vatan'), 'assets/vatan.webp');
      expect(StoreAssetHelper.getStoreAsset('vatan'), 'assets/vatan.webp');

      // Happy Center & MacroCenter & GetirBüyük
      expect(StoreAssetHelper.getStoreAsset('Happy Center'), 'assets/happycenter.webp');
      expect(StoreAssetHelper.getStoreAsset('MacroCenter'), 'assets/macrocenter.webp');
      expect(StoreAssetHelper.getStoreAsset('GetirBüyük'), 'assets/getirbuyuk.webp');

      // MR.DIY
      expect(StoreAssetHelper.getStoreAsset('MR.DIY'), 'assets/mrdiy.webp');
      expect(StoreAssetHelper.getStoreAsset('Mr DIY'), 'assets/mrdiy.webp');

      // İdefix & İncehesap & İtopya
      expect(StoreAssetHelper.getStoreAsset('İdefix'), 'assets/idefix.webp');
      expect(StoreAssetHelper.getStoreAsset('İncehesap'), 'assets/incehesap.webp');
      expect(StoreAssetHelper.getStoreAsset('İtopya'), 'assets/itopya.webp');

      // Fallback durumunda fallbackStoreName veya store-icon
      expect(StoreAssetHelper.getStoreAsset(null, 'ŞOK'), 'assets/sok.webp');
      expect(StoreAssetHelper.getStoreAsset('Bilinmeyen Magaza XYZ'), 'assets/store-icon.png');
    });

    test('Haritalanan tüm asset dosyaları diskte mevcut olmalı', () {
      final sampleStores = [
        'bim', 'a101', 'sok', 'migros', 'carrefoursa', 'metro', 'macrocenter',
        'getir', 'getirbuyuk', 'bizim', 'file', 'happycenter', 'hakmar',
        'hakmarexpress', 'cagri', 'kooperatifmarket', 'watsons', 'gratis',
        'rossmann', 'cetinkaya', 'civil', 'evkur', 'mrdiy', 'teknosa',
        'vatan', 'vestel', 'mediamarkt', 'incehesap', 'itopya', 'havit',
        'trendyol', 'hepsiburada', 'amazon', 'n11', 'pazarama', 'pttavm',
        'idefix', 'boyner', 'beymen', 'mavi', 'defacto', 'zara', 'mango'
      ];

      for (final store in sampleStores) {
        final assetPath = StoreAssetHelper.getStoreAsset(store);
        final file = File(assetPath);
        expect(file.existsSync(), isTrue, reason: '$assetPath dosyası diskte bulunamadı ($store için)!');
      }
    });
  });
}
