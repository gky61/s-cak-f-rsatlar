class Category {
  final String id;
  final String name;
  final String icon;
  final List<String> subcategories;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    this.subcategories = const [],
  });

  static const List<Category> categories = [
    Category(id: 'tumu', name: 'Tümü', icon: '🔥'),
    Category(
      id: 'elektronik',
      name: 'Elektronik',
      icon: '💻',
      subcategories: [
        "Telefon & Aksesuarları",
        "Bilgisayar & Tablet",
        "TV & Ses Sistemleri",
        "Beyaz Eşya & Küçük Ev Aletleri",
        "Fotoğraf & Kamera",
        "Akıllı Ev & Güvenlik"
      ],
    ),
    Category(
      id: 'moda',
      name: 'Moda & Giyim',
      icon: '👗',
      subcategories: [
        "Kadın Giyim",
        "Erkek Giyim",
        "Ayakkabı & Çanta",
        "Saat, Aksesuar & Takı",
        "Çocuk Giyim"
      ],
    ),
    Category(
      id: 'ev_yasam',
      name: 'Ev, Yaşam & Ofis',
      icon: '🏠',
      subcategories: [
        "Mobilya",
        "Ev Tekstili",
        "Mutfak Gereçleri",
        "Aydınlatma & Dekorasyon",
        "Kırtasiye & Ofis Malzemeleri"
      ],
    ),
    Category(
      id: 'anne_bebek',
      name: 'Anne & Bebek',
      icon: '👶',
      subcategories: [
        "Bebek Bezi & Islak Mendil",
        "Bebek Arabası & Oto Koltuğu",
        "Beslenme & Emzirme",
        "Bebek Odası & Güvenlik",
        "Bebek & Çocuk Oyuncakları"
      ],
    ),
    Category(
      id: 'kozmetik',
      name: 'Kozmetik & Bakım',
      icon: '💄',
      subcategories: [
        "Parfüm & Deodorant",
        "Makyaj Ürünleri",
        "Cilt & Yüz Bakımı",
        "Saç Bakımı",
        "Ağız & Diş Bakımı"
      ],
    ),
    Category(
      id: 'spor_outdoor',
      name: 'Spor & Outdoor',
      icon: '⚽',
      subcategories: [
        "Spor Giyim & Ayakkabı",
        "Fitness & Kondisyon",
        "Kamp & Doğa Malzemeleri",
        "Bisiklet & Ekipmanları",
        "Bireysel & Takım Sporları"
      ],
    ),
    Category(
      id: 'supermarket',
      name: 'Süpermarket',
      icon: '🛒',
      subcategories: [
        "Gıda Ürünleri",
        "Deterjan & Temizlik",
        "Kağıt Ürünleri",
        "Kedi & Köpek Ürünleri"
      ],
    ),
    Category(
      id: 'yapi_oto',
      name: 'Yapı Market & Oto',
      icon: '🔧',
      subcategories: [
        "Elektrikli Aletler, Hırdavat & İş Güvenliği",
        "Oto Aksesuar & Bakım",
        "Banyo, Tesisat & Yapı",
        "Bahçe Malzemeleri"
      ],
    ),
    Category(
      id: 'kitap_hobi',
      name: 'Kitap, Müzik & Hobi',
      icon: '📚',
      subcategories: [
        "Kitap & Dergi",
        "Müzik Enstrümanları",
        "Oyun Konsolları & Video Oyunları",
        "Hobi & Sanat Malzemeleri",
        "Kutu Oyunları & Oyuncaklar"
      ],
    ),
    Category(
      id: 'dijital_hizmetler',
      name: 'Dijital & Hizmetler',
      icon: '🌐',
      subcategories: [
        "Abonelik & Yazılım",
        "Yemek & Restoran",
        "Seyahat & Eğlence",
        "Dijital Kod & Oyun Pinleri"
      ],
    ),
    Category(
      id: 'finans_kampanyalar',
      name: 'Finans & Kampanyalar',
      icon: '💳',
      subcategories: [
        "Banka Kampanyaları",
        "Yatırım & Değerli Metaller"
      ],
    ),
    Category(
      id: 'diger',
      name: 'Diğer',
      icon: '📦',
      subcategories: [],
    ),
  ];

  /// Telegram botunun kullandığı kategori ID'lerini uygulama kategori ID'sine çevirir.
  /// Bot: bilgisayar, mobil_cihazlar, konsol_oyun, ev_elektronigi_yasam, ag_yazilim, 'Bilgisayar'
  static const Map<String, String> _botToAppCategoryId = {
    'bilgisayar': 'elektronik',
    'mobil_cihazlar': 'elektronik',
    'konsol_oyun': 'kitap_hobi',
    'ev_elektronigi_yasam': 'ev_yasam',
    'ag_yazilim': 'elektronik',
  };

  /// Ham kategori değerini (bot ID, uygulama ID veya kategori adı) uygulama kategori ID'sine normalize eder.
  static String normalizeCategoryId(String raw) {
    if (raw.isEmpty) return 'diger';
    final lower = raw.trim().toLowerCase();
    // Zaten uygulama ID'si ise aynen döndür
    final isAppId = categories.any((c) => c.id.toLowerCase() == lower && c.id != 'tumu');
    if (isAppId) return lower;
    // Bot ID'si ise eşle
    final mapped = _botToAppCategoryId[lower];
    if (mapped != null) return mapped;
    if (lower == 'bilgisayar') return 'elektronik';
    // Kategori adı olarak kaydedilmişse (örn. "Elektronik") ID'ye çevir
    final byName = categories.where((c) => c.id != 'tumu' && c.name.toLowerCase() == lower);
    if (byName.isNotEmpty) return byName.first.id;
    return 'diger';
  }

  static Category getById(String id) {
    return categories.firstWhere(
      (cat) => cat.id == id,
      orElse: () => categories[0],
    );
  }

  static String getNameById(String id) {
    return getById(id).name;
  }

  // Kategori ismini ID'ye çevir
  static String? getIdByName(String name) {
    try {
      return categories.firstWhere(
        (cat) => cat.name == name,
        orElse: () => categories[0],
      ).id;
    } catch (e) {
      return null;
    }
  }
}
