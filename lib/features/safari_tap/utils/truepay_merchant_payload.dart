/// Helpers for TruePay merchant QR / typed IDs (`partner_…`, `/p/`, `/l/`).
abstract final class TruePayMerchantPayload {
  static bool isMerchantId(String raw) {
    final value = raw.trim();
    return value.startsWith('partner_') && value.length > 'partner_'.length;
  }

  static bool looksLikeProductLink(String raw) {
    final value = raw.trim();
    return value.contains('/l/') ||
        value.contains('truepay://product') ||
        value.contains('truepay://link');
  }

  static bool looksLikeProfileLink(String raw) {
    final value = raw.trim();
    return value.contains('/p/') ||
        value.contains('truepay://merchant') ||
        isMerchantId(value);
  }

  static bool shouldResolve(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return false;
    return value.contains('://') ||
        value.contains('/p/') ||
        value.contains('/l/') ||
        value.startsWith('truepay:');
  }

  /// Extracts `partner_…` from a typed ID, `/p/{id}`, or `truepay://merchant/…`.
  static String? extractMerchantId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (isMerchantId(value)) return value;

    final slashP = RegExp(r'/p/([A-Za-z0-9_-]+)');
    final fromPath = slashP.firstMatch(value)?.group(1);
    if (fromPath != null && fromPath.isNotEmpty) {
      return fromPath.startsWith('partner_') ? fromPath : 'partner_$fromPath';
    }

    final scheme = RegExp(r'truepay://merchant/([A-Za-z0-9_-]+)');
    final fromScheme = scheme.firstMatch(value)?.group(1);
    if (fromScheme != null && fromScheme.isNotEmpty) {
      return fromScheme.startsWith('partner_')
          ? fromScheme
          : 'partner_$fromScheme';
    }

    return null;
  }
}
