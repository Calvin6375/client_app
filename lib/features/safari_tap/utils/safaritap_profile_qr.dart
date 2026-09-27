/// Reads a SafariTap profile QR payload into a Firebase customer id.
///
/// Supported forms:
/// - `https://…/u/{customerId}` (e.g. `/b2bPortal/u/<uid>`)
/// - `truepay://user/{customerId}`
String? parseSafariTapCustomerId(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri != null) {
    if (uri.scheme.toLowerCase() == 'truepay') {
      final host = uri.host.toLowerCase();
      if (host == 'user') {
        if (uri.pathSegments.isNotEmpty) {
          final id = uri.pathSegments.first.trim();
          if (id.isNotEmpty) return id;
        }
        final pathId = uri.path.replaceFirst(RegExp(r'^/'), '').trim();
        if (pathId.isNotEmpty) return pathId;
      }
      if (uri.pathSegments.length >= 2 &&
          uri.pathSegments.first.toLowerCase() == 'user') {
        final id = uri.pathSegments[1].trim();
        if (id.isNotEmpty) return id;
      }
    }

    final segments = uri.pathSegments;
    for (var i = 0; i < segments.length - 1; i++) {
      if (segments[i] == 'u') {
        final id = segments[i + 1].trim();
        if (id.isNotEmpty) return id;
      }
    }
  }

  final match = RegExp(r'/u/([^/?#]+)').firstMatch(value);
  if (match != null) {
    final id = match.group(1)?.trim();
    if (id != null && id.isNotEmpty) return id;
  }

  return null;
}
