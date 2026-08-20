import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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

  static const Map<String, Color> _storeColorMap = {
    // Süpermarket / Marketler & Aktüel
    'bim': Color(0xFF005691),
    'a101': Color(0xFF14B4C8),
    'sok': Color(0xFFFFD200),
    'sokmarket': Color(0xFFFFD200),
    'ceptesok': Color(0xFFFFD200),
    'migros': Color(0xFFEE7C11),
    'migrossanalmarket': Color(0xFFEE7C11),
    'carrefoursa': Color(0xFF0F4C81),
    'carrefour': Color(0xFF0F4C81),
    'metro': Color(0xFF002F6C),
    'metrogrossmarket': Color(0xFF002F6C),
    'macrocenter': Color(0xFF1B1B1B),
    'getir': Color(0xFF5D3EBC),
    'getirbuyuk': Color(0xFF5D3EBC),
    'bizim': Color(0xFFFFCC00),
    'bizimtoptan': Color(0xFFFFCC00),
    'bizimtoptansatis': Color(0xFFFFCC00),
    'bizimtoptansatismagazalari': Color(0xFFFFCC00),
    'file': Color(0xFF3498DB),
    'filemarket': Color(0xFF3498DB),
    'happycenter': Color(0xFF8DC63F),
    'happy': Color(0xFF8DC63F),
    'hakmar': Color(0xFFD32F2F),
    'hakmarexpress': Color(0xFFD32F2F),
    'cagri': Color(0xFFE31B23),
    'cagrihipermarket': Color(0xFFE31B23),
    'cagrimarket': Color(0xFFE31B23),
    'kooperatif': Color(0xFF00755F),
    'kooperatifmarket': Color(0xFF00755F),
    'tarimkredi': Color(0xFF00755F),
    'tarimkredikooperatif': Color(0xFF00755F),
    'tarimkredikooperatifmarket': Color(0xFF00755F),

    // Kozmetik & Bakım
    'watsons': Color(0xFF00A19B),
    'gratis': Color(0xFF8B1E87),
    'rossmann': Color(0xFFE2001A),

    // Giyim / Yaşam / Anne & Bebek
    'cetinkaya': Color(0xFFE31E24),
    'civil': Color(0xFFFF6600),
    'civilim': Color(0xFFFF6600),
    'evkur': Color(0xFF003399),
    'mrdiy': Color(0xFFFFD100),
    'misterdiy': Color(0xFFFFD100),

    // Elektronik / Teknoloji
    'teknosa': Color(0xFFFF5F00),
    'vatan': Color(0xFF005691),
    'vatanbilgisayar': Color(0xFF005691),
    'vestel': Color(0xFFCC0000),
    'mediamarkt': Color(0xFFDF0000),
    'incehesap': Color(0xFF1E88E5),
    'itopya': Color(0xFFFF5722),
    'havit': Color(0xFFE53935),

    // Pazaryerleri & Moda
    'trendyol': Color(0xFFF27A1A),
    'ty': Color(0xFFF27A1A),
    'hepsiburada': Color(0xFFFF6000),
    'hb': Color(0xFFFF6000),
    'amazon': Color(0xFFFF9900),
    'n11': Color(0xFF5A189A),
    'pazarama': Color(0xFF002855),
    'pttavm': Color(0xFFE30613),
    'idefix': Color(0xFFE30613),
    'boyner': Color(0xFF1E293B),
    'beymen': Color(0xFF1A1A1A),
    'mavi': Color(0xFF003366),
    'defacto': Color(0xFF002855),
    'zara': Color(0xFF1E293B),
    'mango': Color(0xFF1E293B),
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

  /// Mağaza adı veya mağaza kodu parametresine göre doğru marka rengini döndürür.
  static Color getStoreColor(String? storeNameOrCode, [String? fallbackStoreName]) {
    if (storeNameOrCode != null && storeNameOrCode.trim().isNotEmpty) {
      final key = normalizeKey(storeNameOrCode);
      if (_storeColorMap.containsKey(key)) {
        return _storeColorMap[key]!;
      }
      for (final entry in _storeColorMap.entries) {
        if (key.startsWith(entry.key) || entry.key.startsWith(key)) {
          return entry.value;
        }
      }
    }

    if (fallbackStoreName != null && fallbackStoreName.trim().isNotEmpty) {
      final key = normalizeKey(fallbackStoreName);
      if (_storeColorMap.containsKey(key)) {
        return _storeColorMap[key]!;
      }
      for (final entry in _storeColorMap.entries) {
        if (key.startsWith(entry.key) || entry.key.startsWith(key)) {
          return entry.value;
        }
      }
    }

    return AppTheme.primary;
  }
}
