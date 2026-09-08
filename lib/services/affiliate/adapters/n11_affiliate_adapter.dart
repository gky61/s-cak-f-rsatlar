import '../base_affiliate_adapter.dart';

/// N11 gelir ortaklığı adaptörü.
class N11AffiliateAdapter extends BaseAffiliateAdapter {
  final String refId;

  N11AffiliateAdapter({
    this.refId = '',
    bool enabled = true,
  }) {
    isEnabled = enabled;
  }

  @override
  bool get isEnabled => super.isEnabled && refId.trim().isNotEmpty;

  @override
  String get storeName => 'N11';

  @override
  String get storeKey => 'n11';

  @override
  bool canHandle(Uri uri) {
    return uri.host.toLowerCase().contains('n11.com');
  }

  @override
  bool isAlreadyAffiliate(Uri uri) {
    if (uri.host.toLowerCase().contains('sl.n11.com')) return false;
    if (refId.isEmpty) return false;
    return uri.queryParameters['ref'] == refId;
  }

  @override
  String convert(Uri uri) {
    if (refId.isEmpty) return uri.toString();

    final newQueryParams = Map<String, String>.from(uri.queryParameters);
    newQueryParams['ref'] = refId;
    return uri.replace(queryParameters: newQueryParams).toString();
  }
}
