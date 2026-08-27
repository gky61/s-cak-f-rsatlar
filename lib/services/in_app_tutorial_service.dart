import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tutorial adımının detaylarını tanımlayan veri modeli
class TutorialStep {
  final String id;
  final String categoryTag;
  final String title;
  final String description;
  final String buttonText;
  final IconData icon;
  final Color accentColor;
  final GlobalKey targetKey;
  final double borderRadius;
  final EdgeInsets padding;
  final bool isCircle;

  const TutorialStep({
    required this.id,
    required this.categoryTag,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.icon,
    required this.accentColor,
    required this.targetKey,
    this.borderRadius = 14.0,
    this.padding = const EdgeInsets.all(6.0),
    this.isCircle = false,
  });
}

/// Uygulama içi interaktif rehber (Tutorial / Spotlight Showcase) yönetim servisi
class InAppTutorialService {
  static const String _prefKeyHasSeenTutorial = 'has_seen_inapp_tutorial_v1';
  static final InAppTutorialService _instance = InAppTutorialService._internal();

  factory InAppTutorialService() => _instance;
  InAppTutorialService._internal();

  // Tur sırasında kullanılacak hedef GlobalKey'ler (8 Ayrı Hedef)
  GlobalKey searchBarKey = GlobalKey();
  GlobalKey aktuelChipKey = GlobalKey();
  GlobalKey kuponlarChipKey = GlobalKey();
  GlobalKey firstDealCardKey = GlobalKey();
  GlobalKey bottomNavPopularKey = GlobalKey();
  GlobalKey bottomNavSavedKey = GlobalKey();
  GlobalKey bottomNavAddKey = GlobalKey();
  GlobalKey bottomNavProfileKey = GlobalKey();

  /// GlobalKey referanslarını yenileyerek eski widget ağacından kalan kilitlenmeleri önler
  void refreshKeys() {
    searchBarKey = GlobalKey();
    aktuelChipKey = GlobalKey();
    kuponlarChipKey = GlobalKey();
    firstDealCardKey = GlobalKey();
    bottomNavPopularKey = GlobalKey();
    bottomNavSavedKey = GlobalKey();
    bottomNavAddKey = GlobalKey();
    bottomNavProfileKey = GlobalKey();
  }

  /// Kullanıcının daha önce turu tamamlayıp tamamlamadığını sorgular
  Future<bool> hasSeenTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKeyHasSeenTutorial) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Turun tamamlandığını kaydeder
  Future<void> markTutorialCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyHasSeenTutorial, true);
    } catch (_) {}
  }

  /// Tur durumunu sıfırlar (tekrar görmek isteyenler için)
  Future<void> resetTutorial() async {
    try {
      refreshKeys();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyHasSeenTutorial);
    } catch (_) {}
  }

  /// FırsatKolik'in 7 temel "Killer Feature" adım listesini oluşturur
  List<TutorialStep> getTutorialSteps() {
    return [
      // 1. ADIM: ARAMA & RADAR (Sıcak Mercan)
      TutorialStep(
        id: 'search_radar',
        categoryTag: 'ARAMA & RADAR',
        title: 'Akıllı Arama & Fırsat Radarı',
        description:
            '🔍 Aradığın ürünü anında bul veya radara ekleyerek 🔔 indirim alarmı kur.',
        buttonText: 'Devam Et',
        icon: Icons.radar_rounded,
        accentColor: const Color(0xFFF97316),
        targetKey: searchBarKey,
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),

      // 2. ADIM: İNDİRİM BROŞÜRLERİ (Gök Mavisi)
      TutorialStep(
        id: 'aktuel_kataloglar',
        categoryTag: 'İNDİRİM BROŞÜRLERİ',
        title: 'Aktüel & Mağaza Broşürleri',
        description:
            '🛒 Popüler mağazaların haftalık indirim broşürlerini ve kampanyalarını tek yerden incele.',
        buttonText: 'Sıradaki',
        icon: Icons.auto_stories_rounded,
        accentColor: const Color(0xFF38BDF8),
        targetKey: aktuelChipKey,
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),

      // 3. ADIM: İNDİRİM KUPONLARI (Lavanta / Mor)
      TutorialStep(
        id: 'indirim_kuponlari',
        categoryTag: 'İNDİRİM KODLARI',
        title: 'Mağaza Kuponları',
        description:
            '🎟️ Trendyol, Hepsiburada, Amazon ve 20+ mağazanın güncel kuponlarını tek tıkla kopyala.',
        buttonText: 'Sıradaki',
        icon: Icons.confirmation_number_rounded,
        accentColor: const Color(0xFFA78BFA),
        targetKey: kuponlarChipKey,
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),

      // 4. ADIM: FIRSAT KARTI & ETKİLEŞİM (Sıcak Gül Kırmızısı)
      TutorialStep(
        id: 'community_thermometer',
        categoryTag: 'FIRSAT ETKİLEŞİMİ',
        title: 'Fırsatı İncele & Değerlendir',
        description:
            'Fırsat detaylarını incele; 🔥/🥶 ile oyla, 💬 yorum yap ve stok biterse ⌛ Bitti bildirimi gönder.',
        buttonText: 'Sıradaki',
        icon: Icons.local_fire_department_rounded,
        accentColor: const Color(0xFFF87171),
        targetKey: firstDealCardKey,
        borderRadius: 16,
        padding: const EdgeInsets.all(4),
      ),

      // 5. ADIM: POPÜLER FIRSATLAR (Alev Turuncusu)
      TutorialStep(
        id: 'popular_deals',
        categoryTag: 'POPÜLER FIRSATLAR',
        title: 'Günün Trend İndirimleri',
        description:
            '⚡ Topluluk oylarıyla öne çıkan son 48 saatin 🔥 en sıcak fırsatlarını keşfet.',
        buttonText: 'Sıradaki',
        icon: Icons.whatshot_rounded,
        accentColor: const Color(0xFFFB923C),
        targetKey: bottomNavPopularKey,
        borderRadius: 20,
        padding: const EdgeInsets.all(6),
        isCircle: true,
      ),

      // 6. ADIM: AKILLI LİNK ANALİZİ & FIRSAT PAYLAŞ (Pembe Gül)
      TutorialStep(
        id: 'submit_deal',
        categoryTag: 'AKILLI LİNK ANALİZİ',
        title: 'Yapay Zeka Destekli Paylaşım',
        description:
            '🔗 Paylaşmak istediğin ürünün linkini yapıştır; ürün detaylarını 🤖 yapay zeka otomatik doldursun.',
        buttonText: 'Sıradaki',
        icon: Icons.add_circle_outline_rounded,
        accentColor: const Color(0xFFF472B6),
        targetKey: bottomNavAddKey,
        borderRadius: 20,
        padding: const EdgeInsets.all(6),
        isCircle: true,
      ),

      // 7. ADIM: KAYDEDİLENLER & FAVORİ KATEGORİLERİM (Zümrüt Yeşili)
      TutorialStep(
        id: 'saved_and_categories',
        categoryTag: 'KAYDEDİLENLER & TAKİP',
        title: 'Kaydedilenler & Özel Akışın',
        description:
            '📌 Fırsatları favorilerine ekle, takip ettiğin kategorilere özel indirim akışını oluştur.',
        buttonText: 'Sıradaki',
        icon: Icons.bookmark_rounded,
        accentColor: const Color(0xFF34D399),
        targetKey: bottomNavSavedKey,
        borderRadius: 20,
        padding: const EdgeInsets.all(6),
        isCircle: true,
      ),

      // 8. ADIM: PROFİLİM & AVCI MERKEZİ (Asil İndigo)
      TutorialStep(
        id: 'profile_hub',
        categoryTag: 'PROFİL & AYARLAR',
        title: 'Profilim & Avcı Merkezi',
        description:
            '💬 Mesajlarına ulaş, 🔔 bildirimlerini özelleştir, 🏆 avcı rozetlerini topla ve hesap ayarlarını yönet.',
        buttonText: 'Keşfe Başla 🎉',
        icon: Icons.person_rounded,
        accentColor: const Color(0xFF818CF8),
        targetKey: bottomNavProfileKey,
        borderRadius: 20,
        padding: const EdgeInsets.all(6),
        isCircle: true,
      ),
    ];
  }
}
