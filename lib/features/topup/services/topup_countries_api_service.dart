import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/utils/logger.dart';

/// Loads enabled top-up countries from the backend
/// (`GET …/api/countries`).
///
/// Response shape:
/// `{ "success": true, "data": { "countries": ["KE","NG",…] } }`
/// Entries may be ISO 3166-1 alpha-2 **or** ISO 4217 currency codes
/// (e.g. `KES`, `NGN`); both are resolved against [TopupDepositCountry].
final class TopupCountriesApiService {
  TopupCountriesApiService();

  /// Ordered list matching the API; unknown codes are skipped (see logs).
  Future<List<TopupDepositCountry>> fetchEnabledCountries() async {
    final uri = CloudFunctionsApiConfig.countriesUri();
    const headers = {'Accept': 'application/json'};

    Logger.debug(
      'TopupCountriesApiService request:\n'
      '  method: GET\n'
      '  url: $uri\n'
      '  headers: $headers\n'
      '  requestBody: <none> (GET has no entity body)',
    );

    final response = await http.get(uri, headers: headers);

    Logger.debug(
      'TopupCountriesApiService response:\n'
      '  status: ${response.statusCode}\n'
      '  responseBody: ${response.body}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TopupCountriesApiException(
          'Server returned ${response.statusCode}');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw TopupCountriesApiException('Invalid response from server');
    }
    if (decoded is! Map<String, dynamic>) {
      throw TopupCountriesApiException('Invalid JSON root');
    }

    final success = decoded['success'];
    if (success != true) {
      Logger.debug('TopupCountriesApiService: success != true: $decoded');
      throw TopupCountriesApiException('Request was not successful');
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw TopupCountriesApiException('Missing data object');
    }

    final raw = data['countries'];
    if (raw == null) {
      return const [];
    }
    if (raw is! List) {
      throw TopupCountriesApiException('countries is not a list');
    }

    final out = <TopupDepositCountry>[];
    final seenCurrencyCodes = <String>{};
    for (final item in raw) {
      if (item is! String) continue;
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      final mapped = TopupDepositCountry.fromIsoAlpha2(trimmed) ??
          TopupDepositCountry.forDepositCode(trimmed);
      if (mapped != null) {
        if (seenCurrencyCodes.add(mapped.code)) {
          out.add(mapped);
        }
      } else {
        Logger.debug(
            'TopupCountriesApiService: no catalog entry for "$trimmed" — skipped');
      }
    }
    return out;
  }
}

class TopupCountriesApiException implements Exception {
  TopupCountriesApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
