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
        "Fotoğraf & Kamera"
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
        "Saat & Aksesuar",
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
        "Bebek Oyuncakları"
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
        "Bisiklet & Ekipmanları"
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
        "Elektrikli Aletler & Hırdavat",
        "Oto Aksesuar & Bakım",
        "Banyo & Tesisat",
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
        "Hobi & Sanat Malzemeleri"
      ],
    ),
  ];

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
