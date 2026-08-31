import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/core/http/c2b_http_codec.dart';
import 'package:pretium/utils/logger.dart';

/// Response from `GET /api/countries`.
///
/// The backend currently returns ISO 4217 / asset codes in both
/// [countries] and [currencies] (sourced from customer rates).
class CountriesCatalog {
  const CountriesCatalog({
    required this.countries,
    required this.currencies,
    this.source,
    this.updatedAt,
  });

  final List<String> countries;
  final List<String> currencies;
  final String? source;
  final String? updatedAt;

  /// Prefer [currencies]; fall back to [countries] when empty.
  List<String> get codes {
    final raw = currencies.isNotEmpty ? currencies : countries;
    return [
      for (final code in raw)
        if (code.trim().isNotEmpty) code.trim().toUpperCase(),
    ];
  }

  /// Fiat-only codes for Deposit / top-up pickers.
  List<String> get fiatCodes =>
      codes.where((c) => !_cryptoAssetCodes.contains(c)).toList()..sort();

  static const Set<String> _cryptoAssetCodes = {
    'BTC',
    'ETH',
    'SOL',
    'USDT',
    'USDC',
    'BNB',
    'TRX',
    'MATIC',
    'POL',
  };

  factory CountriesCatalog.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString().trim().toUpperCase(),
      ];
    }

    return CountriesCatalog(
      countries: parseList(json['countries']),
      currencies: parseList(json['currencies']),
      source: json['source']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

/// Client for `GET /api/countries` on `functions:api`.
class CountriesApiService {
  CountriesApiService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  final C2bHttpCodec _codec = C2bHttpCodec.instance;

  static CountriesCatalog? _cache;
  static DateTime? _cacheAt;
  static const Duration _ttl = Duration(minutes: 30);

  /// Cached catalog when still fresh.
  static CountriesCatalog? get cached =>
      _cacheAt != null && DateTime.now().difference(_cacheAt!) < _ttl
          ? _cache
          : null;

  Future<CountriesCatalog> fetchCountries({bool forceRefresh = false}) async {
    final hit = cached;
    if (!forceRefresh && hit != null) return hit;

    final uri = CloudFunctionsApiConfig.countriesUri();
    Logger.info('CountriesApiService GET /api/countries');

    final response = await _http.get(
      uri,
      headers: await _codec.mergeHeaders({
        'Accept': 'application/json',
      }),
    );

    final plain = await _codec.plainResponseBody(response);
    final decoded = json.decode(plain);
    if (decoded is! Map) {
      throw Exception('Invalid countries API response');
    }
    final body = Map<String, dynamic>.from(decoded);

    if (response.statusCode != 200 || body['success'] != true) {
      final error = body['error']?.toString() ?? 'Failed to load countries';
      throw Exception(error);
    }

    final dataRaw = body['data'];
    if (dataRaw is! Map) {
      throw Exception('Invalid countries API data');
    }

    final catalog =
        CountriesCatalog.fromJson(Map<String, dynamic>.from(dataRaw));
    _cache = catalog;
    _cacheAt = DateTime.now();
    Logger.success(
      'Countries loaded: ${catalog.fiatCodes.length} fiat '
      '(${catalog.codes.length} total)',
    );
    return catalog;
  }
}
