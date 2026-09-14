/// Asset path migration utility & Avatar Catalog.
///
/// Eski .jpg, .jpeg, .png asset yollarını yeni .webp formatına dönüştürür
/// ve eski kök dizindeki avatar yollarını yeni `assets/avatars/` dizinine yönlendirir.
String migrateAssetPath(String path) {
  if (path.isEmpty) return '';
  final clean = path.trim();

  // 1. Eski profil avatar yollarını yeni standart dizine haritala (Geriye Dönük Uyumluluk)
  final lower = clean.toLowerCase();
  if (lower.contains('kullanıcı pp') || lower.contains('kullanici pp')) {
    return AppAvatars.cat;
  }
  if (lower.contains('kkpp')) {
    return AppAvatars.duck;
  }
  if (lower.contains('ayi') || lower.contains('ayı')) {
    return AppAvatars.duck;
  }
  if (lower.contains('kullanıcı profili') || lower.contains('kullanici profili')) {
    return AppAvatars.duck;
  }
  if (lower == 'assets/profil.jpg' || lower == 'assets/profil.webp') {
    return AppAvatars.duck;
  }

  // 2. Eski uzantı normalizasyonu (.jpg, .jpeg, .png -> .webp)
  if (clean.startsWith('assets/')) {
    if (clean.endsWith('.jpg') || clean.endsWith('.jpeg') || clean.endsWith('.png')) {
      final lastDot = clean.lastIndexOf('.');
      if (lastDot != -1) {
        return '${clean.substring(0, lastDot)}.webp';
      }
    }
  }

  return clean;
}

/// Standart Hazır Profil Avatarları Kataloğu
class AppAvatars {
  // Orijinal Temel Avatarlar
  static const String cat = 'assets/avatars/avatar_cat.webp';
  static const String duck = 'assets/avatars/avatar_duck.webp';

  // Karakter & Fırsat Avatarları
  static const String kuponKrali = 'assets/avatars/avatar_kupon_krali.webp';
  static const String dedektif = 'assets/avatars/avatar_dedektif.webp';
  static const String alisverisci = 'assets/avatars/avatar_alisverisci.webp';

  // Yaşam & İlgi Alanı Avatarları
  static const String oyuncu = 'assets/avatars/avatar_oyuncu.webp';
  static const String teknoloji = 'assets/avatars/avatar_teknoloji_meraklisi.webp';
  static const String kampci = 'assets/avatars/avatar_kamp_tutkunu.webp';
  static const String fotografci = 'assets/avatars/avatar_fotograf_gezgini.webp';
  static const String kahvesever = 'assets/avatars/avatar_kahve_tutkunu.webp';
  static const String pizzasever = 'assets/avatars/avatar_pizza_sever.webp';
  static const String kitapkurdu = 'assets/avatars/avatar_kitap_kurdu.webp';
  static const String muziksever = 'assets/avatars/avatar_muzik_tutkunu.webp';
  static const String fitness = 'assets/avatars/avatar_fitness_tutkunu.webp';
  static const String guzellik = 'assets/avatars/avatar_guzellik_meraklisi.webp';
  static const String dekorasyon = 'assets/avatars/avatar_ev_dekorasyoncusu.webp';
  static const String mutfak = 'assets/avatars/avatar_mutfak_meraklisi.webp';
  static const String uykucu = 'assets/avatars/avatar_uykucu.webp';

  /// Kullanıcı seçim galerisine sunulan tüm hazır avatarlar (18 adet)
  static const List<String> all = [
    // Öne Çıkan Karakterler & Maskotlar
    kuponKrali,
    dedektif,
    cat,
    duck,
    uykucu,

    // İlgi Alanları & Yaşam Tarzı
    alisverisci,
    oyuncu,
    teknoloji,
    kampci,
    fotografci,
    kahvesever,
    pizzasever,
    kitapkurdu,
    muziksever,
    fitness,
    guzellik,
    dekorasyon,
    mutfak,
  ];

  /// Avatar başlık/etiket bilgisi
  static String getLabel(String path) {
    if (path.contains('avatar_kupon_krali')) return 'Kupon Kralı';
    if (path.contains('avatar_dedektif')) return 'Fırsat Dedektifi';
    if (path.contains('avatar_cat')) return 'Kara Kedi';
    if (path.contains('avatar_duck')) return 'Sarı Civciv';
    if (path.contains('avatar_uykucu')) return 'Uykucu Panda';

    if (path.contains('avatar_alisverisci')) return 'Alışveriş Tutkunu';
    if (path.contains('avatar_oyuncu')) return 'Oyuncu (Gamer)';
    if (path.contains('avatar_teknoloji_meraklisi')) return 'Teknoloji Kurdu';
    if (path.contains('avatar_kamp_tutkunu')) return 'Kampçı Gezgin';
    if (path.contains('avatar_fotograf_gezgini')) return 'Fotoğrafçı';
    if (path.contains('avatar_kahve_tutkunu')) return 'Kahve Sever';
    if (path.contains('avatar_pizza_sever')) return 'Gurme Pizza';
    if (path.contains('avatar_kitap_kurdu')) return 'Kitap Kurdu';
    if (path.contains('avatar_muzik_tutkunu')) return 'Müzik Aşığı';
    if (path.contains('avatar_fitness_tutkunu')) return 'Spor & Fitness';
    if (path.contains('avatar_guzellik_meraklisi')) return 'Güzellik & Bakım';
    if (path.contains('avatar_ev_dekorasyoncusu')) return 'Ev & Tasarım';
    if (path.contains('avatar_mutfak_meraklisi')) return 'Mutfak Şefi';

    return 'Avatar';
  }
}
