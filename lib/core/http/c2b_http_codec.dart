import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pretium/core/crypto/c2b_encryption_service.dart';
import 'package:pretium/core/crypto/c2b_payload_crypto.dart';
import 'package:pretium/utils/logger.dart';

/// Applies C2B payload encryption headers and body/response transforms.
final class C2bHttpCodec {
  C2bHttpCodec._();

  static final C2bHttpCodec instance = C2bHttpCodec._();

  static const encryptedHeader = 'x-truepay-encrypted';
  static const keyIdHeader = 'x-truepay-key-id';

  static const _sensitiveJsonKeys = {'password', 'token', 'authorization'};

  C2bEncryptionService get _encryption => C2bEncryptionService.instance;

  Future<Map<String, String>> mergeHeaders(Map<String, String> headers) async {
    final ctx = _encryption.activeContext();
    if (ctx == null) return headers;
    return {
      ...headers,
      'X-TruePay-Encrypted': '1',
      'X-TruePay-Key-Id': ctx.keyId,
    };
  }

  /// Returns wire-format body (encrypted envelope or original plaintext JSON).
  Future<String> encodeJsonBody(String plainJson) async {
    final ctx = _encryption.activeContext();
    if (ctx == null) return plainJson;

    Logger.debug('C2B encrypt — before:\n${_logSafeJson(plainJson)}');

    final envelope = C2bPayloadCrypto.encryptPlaintext(plainJson, ctx.key, ctx.keyId);
    final wireBody = jsonEncode(envelope);

    Logger.debug('C2B encrypt — after (kid=${ctx.keyId}):\n${_formatEnvelopeForLog(envelope)}');
    Logger.debug('C2B encrypt — raw wire body:\n$wireBody');

    return wireBody;
  }

  Future<String> plainResponseBody(http.Response response) async {
    if (!_isEncryptedResponse(response)) return response.body;

    final ctx = _encryption.activeContext();
    if (ctx == null) {
      throw StateError('Encrypted response received but C2B encryption is not configured');
    }

    Logger.debug(
      'C2B decrypt — raw wire response (HTTP ${response.statusCode}):\n'
      '${response.body}',
    );

    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(response.body);
      envelope = decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      throw const FormatException('Encrypted response is not valid JSON');
    }

    Logger.debug(
      'C2B decrypt — before (kid=${envelope['kid']}, header=${response.headers[encryptedHeader]}):\n'
      '${_formatEnvelopeForLog(envelope)}',
    );

    final plainBody = C2bPayloadCrypto.decryptEnvelope(envelope, ctx.key);

    Logger.debug('C2B decrypt — after:\n${_logSafeJson(plainBody)}');

    return plainBody;
  }

  bool _isEncryptedResponse(http.Response response) {
    if (response.headers[encryptedHeader] == '1') return true;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      return decoded['v'] == 1 && decoded['data'] is String;
    } catch (_) {
      return false;
    }
  }

  String _logSafeJson(String json) {
    try {
      final decoded = jsonDecode(json);
      final redacted = _redactSensitive(decoded);
      return const JsonEncoder.withIndent('  ').convert(redacted);
    } catch (_) {
      return json;
    }
  }

  Object? _redactSensitive(Object? value) {
    if (value is Map) {
      return value.map((key, v) {
        if (key is String && _sensitiveJsonKeys.contains(key.toLowerCase())) {
          return MapEntry(key, '***');
        }
        return MapEntry(key, _redactSensitive(v));
      });
    }
    if (value is List) {
      return value.map(_redactSensitive).toList();
    }
    return value;
  }

  String _formatEnvelopeForLog(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    final dataLen = data is String ? data.length : 0;
    final preview = data is String && data.isNotEmpty
        ? '${data.substring(0, data.length < 32 ? data.length : 32)}…'
        : '';

    return const JsonEncoder.withIndent('  ').convert({
      'v': envelope['v'],
      'kid': envelope['kid'],
      'data': '<base64 $dataLen chars> $preview',
    });
  }
}
