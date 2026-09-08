/// Response from `POST /safari-card/merchants/resolve`.
class SafariTapMerchantResolve {
  const SafariTapMerchantResolve({
    required this.kind,
    this.merchantId,
    this.partnerName,
    this.checkoutUrl,
    this.linkId,
  });

  /// `profile` (merchant pay) or `product` (hosted /l/ checkout).
  final String kind;
  final String? merchantId;
  final String? partnerName;
  final String? checkoutUrl;
  final String? linkId;

  bool get isProfile => kind.toLowerCase() == 'profile';

  bool get isProduct => kind.toLowerCase() == 'product';

  factory SafariTapMerchantResolve.fromJson(Map<String, dynamic> json) {
    final merchantId = _string(json['merchantId'] ?? json['merchant_id']);
    final partnerName = _string(
      json['partnerName'] ?? json['partner_name'] ?? json['name'],
    );
    final checkoutUrl = _string(
      json['checkoutUrl'] ??
          json['checkout_url'] ??
          json['hostedUrl'] ??
          json['url'],
    );
    final linkId = _string(json['linkId'] ?? json['link_id']);
    var kind = (json['kind'] ?? json['type'] ?? '').toString().trim();
    if (kind.isEmpty) {
      if (checkoutUrl != null || linkId != null) {
        kind = 'product';
      } else if (merchantId != null) {
        kind = 'profile';
      }
    }
    return SafariTapMerchantResolve(
      kind: kind,
      merchantId: merchantId,
      partnerName: partnerName,
      checkoutUrl: checkoutUrl,
      linkId: linkId,
    );
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
