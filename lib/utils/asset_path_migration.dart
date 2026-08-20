/// Asset path migration utility.
///
/// Eski .jpg, .jpeg, .png asset yollarını yeni .webp formatına dönüştürür.
/// Firestore'da veya yerelde kayıtlı eski profil resmi yolları .jpg olabilir,
/// ancak asset dosyaları artık .webp formatında.
String migrateAssetPath(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('assets/')) {
    if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
      final lastDot = path.lastIndexOf('.');
      if (lastDot != -1) {
        return '${path.substring(0, lastDot)}.webp';
      }
    }
  }
  return path;
}
