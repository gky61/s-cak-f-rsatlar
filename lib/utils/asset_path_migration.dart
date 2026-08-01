/// Asset path migration utility.
///
/// Eski .jpg asset yollarını yeni .webp formatına dönüştürür.
/// Firestore'da kayıtlı eski profil resmi yolları .jpg olabilir,
/// ancak asset dosyaları artık .webp formatında.
String migrateAssetPath(String path) {
  if (path.startsWith('assets/') && path.endsWith('.jpg')) {
    return '${path.substring(0, path.length - 4)}.webp';
  }
  return path;
}
