import '../base_affiliate_adapter.dart';

/// GittiGidiyor gelir ortaklığı adaptörü.
class GittigidiyorAffiliateAdapter extends BaseAffiliateAdapter {
  final String affiliateId;

  GittigidiyorAffiliateAdapter({
    this.affiliateId = '',
    bool enabled = true,
  }) {
    isEnabled = enabled;
  }

  @override
  bool get isEnabled => super.isEnabled && affiliateId.trim().isNotEmpty;

  @override
  String get storeName => 'GittiGidiyor';

  @override
  String get storeKey => 'gittigidiyor';

  @override
  bool canHandle(Uri uri) {
    return uri.host.toLowerCase().contains('gittigidiyor.com');
  }

  @override
  bool isAlreadyAffiliate(Uri uri) {
    if (affiliateId.isEmpty) return false;
    return uri.queryParameters['affiliateId'] == affiliateId;
  }

  @override
  String convert(Uri uri) {
    if (affiliateId.isEmpty) return uri.toString();

    final newQueryParams = Map<String, String>.from(uri.queryParameters);
    newQueryParams['affiliateId'] = affiliateId;
    return uri.replace(queryParameters: newQueryParams).toString();
  }
}
