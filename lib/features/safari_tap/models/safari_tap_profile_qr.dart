import 'dart:convert';
import 'dart:typed_data';

class SafariTapProfileQr {
  const SafariTapProfileQr({
    required this.customerId,
    required this.displayName,
    required this.qrPayload,
    required this.qrCode,
  });

  final String customerId;
  final String displayName;
  final String qrPayload;
  final String qrCode;

  factory SafariTapProfileQr.fromJson(Map<String, dynamic> json) {
    return SafariTapProfileQr(
      customerId: json['customerId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString() ?? '',
      qrCode: json['qrCode']?.toString() ?? '',
    );
  }

  Uint8List? get pngBytes {
    final raw = qrCode.trim();
    if (raw.isEmpty) return null;
    final comma = raw.indexOf(',');
    final b64 = comma >= 0 ? raw.substring(comma + 1) : raw;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}
