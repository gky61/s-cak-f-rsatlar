class Category {
  final String id;
  final String name;
  final String icon;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
  });

  static const List<Category> categories = [
    Category(id: 'tumu', name: 'Tümü', icon: '🔥'),
    Category(id: 'bilgisayar', name: 'Bilgisayar', icon: '💻'),
    Category(id: 'telefon', name: 'Telefon', icon: '📱'),
    Category(id: 'tablet', name: 'Tablet', icon: '📲'),
    Category(id: 'ekran_karti', name: 'Ekran Kartı', icon: '🎮'),
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
}

