import '../base_affiliate_adapter.dart';

/// Trendyol gelir ortaklığı adaptörü.
class TrendyolAffiliateAdapter extends BaseAffiliateAdapter {
  final String boutiqueId;

  TrendyolAffiliateAdapter({
    this.boutiqueId = '',
    bool enabled = true,
  }) {
    isEnabled = enabled;
  }

  @override
  bool get isEnabled => super.isEnabled && boutiqueId.trim().isNotEmpty;

  @override
  String get storeName => 'Trendyol';

  @override
  String get storeKey => 'trendyol';

  @override
  bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('trendyol.com') || host.contains('ty.gl');
  }

  @override
  bool isAlreadyAffiliate(Uri uri) {
    if (uri.host.toLowerCase().contains('ty.gl')) return false;
    if (boutiqueId.isEmpty) return false;
    return uri.queryParameters['boutiqueId'] == boutiqueId;
  }

  @override
  String convert(Uri uri) {
    if (boutiqueId.isEmpty) return uri.toString();

    final newQueryParams = Map<String, String>.from(uri.queryParameters);
    newQueryParams['boutiqueId'] = boutiqueId;
    return uri.replace(queryParameters: newQueryParams).toString();
  }
}
