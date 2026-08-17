/// Mağaza isimleri ve kodları için merkezi logo asset çözümleyici.
///
/// Türkçe karakterleri, büyük/küçük harf farklılıklarını, boşluk/tire/nokta
/// ve mağaza takılarını (örn: "ŞOK", "Bizim Toptan", "Çağrı Hipermarket", "BİM", "A-101")
/// otomatik normalize ederek doğru asset yolunu (`assets/{store}.webp`) döndürür.
class StoreAssetHelper {
  StoreAssetHelper._();

  /// Verilen metni Türkçe karakterlerden arındırıp normalize eder.
  static String normalizeKey(String input) {
    var s = input.trim().toLowerCase();
    // Türkçe karakterleri normalize et
    s = s
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
    // Alfanümerik olmayan karakterleri kaldır
    s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return s;
  }

  static const Map<String, String> _storeAssetMap = {
    // Süpermarket / Marketler & Aktüel
    'bim': 'assets/bim.webp',
    'a101': 'assets/a101.webp',
    'sok': 'assets/sok.webp',
    'sokmarket': 'assets/sok.webp',
    'ceptesok': 'assets/sok.webp',
    'migros': 'assets/migros.webp',
    'migrossanalmarket': 'assets/migros.webp',
    'carrefoursa': 'assets/carrefoursa.webp',
    'carrefour': 'assets/carrefoursa.webp',
    'metro': 'assets/metro.webp',
    'metrogrossmarket': 'assets/metro.webp',
    'macrocenter': 'assets/macrocenter.webp',
    'getir': 'assets/getir.webp',
    'getirbuyuk': 'assets/getirbuyuk.webp',
    'bizim': 'assets/bizim.webp',
    'bizimtoptan': 'assets/bizim.webp',
    'bizimtoptansatis': 'assets/bizim.webp',
    'bizimtoptansatismagazalari': 'assets/bizim.webp',
    'file': 'assets/file.webp',
    'filemarket': 'assets/file.webp',
    'happycenter': 'assets/happycenter.webp',
    'happy': 'assets/happycenter.webp',
    'hakmar': 'assets/hakmar.webp',
    'hakmarexpress': 'assets/hakmar-express.webp',
    'cagri': 'assets/cagri.webp',
    'cagrihipermarket': 'assets/cagri.webp',
    'cagrimarket': 'assets/cagri.webp',
    'kooperatif': 'assets/kooperatif.webp',
    'kooperatifmarket': 'assets/kooperatif.webp',
    'tarimkredi': 'assets/kooperatif.webp',
    'tarimkredikooperatif': 'assets/kooperatif.webp',
    'tarimkredikooperatifmarket': 'assets/kooperatif.webp',

    // Kozmetik & Bakım
    'watsons': 'assets/watsons.webp',
    'gratis': 'assets/gratis.webp',
    'rossmann': 'assets/rossmann.webp',

    // Giyim / Yaşam / Anne & Bebek
    'cetinkaya': 'assets/cetinkaya.webp',
    'civil': 'assets/civil.webp',
    'civilim': 'assets/civil.webp',
    'evkur': 'assets/evkur.webp',
    'mrdiy': 'assets/mrdiy.webp',
    'misterdiy': 'assets/mrdiy.webp',

    // Elektronik / Teknoloji
    'teknosa': 'assets/teknosa.webp',
    'vatan': 'assets/vatan.webp',
    'vatanbilgisayar': 'assets/vatan.webp',
    'vestel': 'assets/vestel.webp',
    'mediamarkt': 'assets/mediamarkt.webp',
    'incehesap': 'assets/incehesap.webp',
    'itopya': 'assets/itopya.webp',
    'havit': 'assets/havit.webp',

    // Pazaryerleri & Moda
    'trendyol': 'assets/trendyol.webp',
    'ty': 'assets/trendyol.webp',
    'hepsiburada': 'assets/hepsiburada.webp',
    'hb': 'assets/hepsiburada.webp',
    'amazon': 'assets/amazon.webp',
    'n11': 'assets/n11.webp',
    'pazarama': 'assets/pazarama.webp',
    'pttavm': 'assets/pttavm.webp',
    'idefix': 'assets/idefix.webp',
    'boyner': 'assets/boyner.webp',
    'beymen': 'assets/beymen.webp',
    'mavi': 'assets/mavi.webp',
    'defacto': 'assets/defacto.webp',
    'zara': 'assets/zara.webp',
    'mango': 'assets/mango.webp',
  };

  /// Mağaza adı veya mağaza kodu parametresine göre doğru logo asset yolunu döndürür.
  static String getStoreAsset(String? storeNameOrCode, [String? fallbackStoreName]) {
    if (storeNameOrCode != null && storeNameOrCode.trim().isNotEmpty) {
      final key = normalizeKey(storeNameOrCode);
      if (_storeAssetMap.containsKey(key)) {
        return _storeAssetMap[key]!;
      }

      // Kısmi eşleşme kontrolü (örn: "şok marketler zinciri" -> "sok")
      for (final entry in _storeAssetMap.entries) {
        if (key.startsWith(entry.key) || entry.key.startsWith(key)) {
          return entry.value;
        }
      }
    }

    if (fallbackStoreName != null && fallbackStoreName.trim().isNotEmpty) {
      final key = normalizeKey(fallbackStoreName);
      if (_storeAssetMap.containsKey(key)) {
        return _storeAssetMap[key]!;
      }
      for (final entry in _storeAssetMap.entries) {
        if (key.startsWith(entry.key) || entry.key.startsWith(key)) {
          return entry.value;
        }
      }
    }

    return 'assets/store-icon.png';
  }
}
