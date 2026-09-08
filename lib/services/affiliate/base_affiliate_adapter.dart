/// Her mağazanın gelir ortaklığı (affiliate) dönüşüm ve kural motorunu izole eden temel arayüz.
abstract class BaseAffiliateAdapter {
  /// Kullanıcıya gösterilecek mağaza adı (ör. 'Teknosa', 'Trendyol')
  String get storeName;

  /// Dahili mağaza anahtarı (ör. 'teknosa', 'trendyol')
  String get storeKey;

  /// Adaptörün aktif olup olmadığını belirten kill-switch (varsayılan: true)
  bool isEnabled = true;

  /// Verilen URL'in bu adaptörün etki alanında olup olmadığını kontrol eder.
  bool canHandle(Uri uri);

  /// Linkin zaten bu mağazaya ait geçerli bir affiliate / yönlendirme linki olup olmadığını kontrol eder.
  bool isAlreadyAffiliate(Uri uri);

  /// Standart/temiz ürün URL'sini mağaza özelindeki affiliate deep-link'e dönüştürür.
  String convert(Uri uri);

  /// Adaptörün canlı affiliate akışına hazır ve test edilmiş olup olmadığını belirtir.
  /// Taslak/demo adaptörler false döner; yalnızca doğrulanmış adaptörler (örn. Teknosa) true döner.
  bool get isAffiliateReady => false;
}


