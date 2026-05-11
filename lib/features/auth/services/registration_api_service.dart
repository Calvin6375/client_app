import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/utils/logger.dart';

/// Registers a customer against the HTTP API (`POST …/api/register`).
///
/// Request body includes [Institution] and [Channel] as required by the backend.
final class RegistrationApiService {
  RegistrationApiService();

  static const String institution = 'Customer App';
  static const String channel = 'C2B';

  /// [phoneNumberE164] should include a leading `+` (e.g. `+254744555666`).
  Future<void> registerCustomer({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumberE164,
    required String password,
  }) async {
    final uri = CloudFunctionsApiConfig.registerUri();
    final body = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumberE164,
      'password': password,
      'Institution': institution,
      'Channel': channel,
    };

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final bodyJson = jsonEncode(body);

    Logger.info('📤 RegistrationApiService POST $uri');
    Logger.debug(
      '   body (password redacted): ${jsonEncode({
        ...body,
        'password': '***',
      })}',
    );

    final response = await http.post(uri, headers: headers, body: bodyJson);

    Logger.info(
      '📥 RegistrationApiService response: ${response.statusCode}\n'
      '   body: ${response.body}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RegistrationApiException(
        _messageFromResponse(response.statusCode, response.body),
      );
    }
  }

  String _messageFromResponse(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final msg = decoded['message'] ?? decoded['error'] ?? decoded['detail'];
        if (msg is String && msg.trim().isNotEmpty) {
          return msg.trim();
        }
      }
    } catch (_) {
      // ignore
    }
    return 'Registration request failed ($statusCode)';
  }
}

class RegistrationApiException implements Exception {
  RegistrationApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
