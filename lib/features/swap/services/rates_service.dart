import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/features/swap/services/exchange_quote.dart';
import 'package:pretium/utils/logger.dart';

/// Customer rates model for buy/sell rates
class CustomerRates {
  final double buyRate; // Rate when buying USDT with fiat
  final double sellRate; // Rate when selling USDT for fiat

  CustomerRates({required this.buyRate, required this.sellRate});
}

/// Rate service that fetches exchange rates from the backend API
/// Uses customer rates (buyRate/sellRate) from /api/customer-rates endpoint for customer transactions
/// Falls back to /api/binance/rates for reference rates
class RatesService {
  /// Same host as `/api/countries` and other HTTP Cloud Functions.
  static String get _baseUrl => CloudFunctionsApiConfig.baseApiUrl;

  // Cache for rates to avoid excessive API calls
  final Map<String, double> _pairToRate = {};
  final Map<String, DateTime> _rateCacheTime = {};

  // Cache for customer rates (buyRate/sellRate)
  final Map<String, CustomerRates> _customerRatesCache = {};
  final Map<String, DateTime> _customerRatesCacheTime = {};

  /// Last successful customer-rates payload (for UI state / debugging).
  Map<String, dynamic>? lastCustomerRatesPayload;

  // Cache duration: 5 minutes (rates are valid for 5-10 minutes per API docs)
  static const Duration _cacheDuration = Duration(minutes: 5);

  final StreamController<Map<String, double>> _controller =
      StreamController.broadcast();
  Timer? _refreshTimer;

  RatesService() {
    // Initialize with default rates for common pairs
    // These will be replaced with real rates from API once fetched
    final now = DateTime.now();
    _pairToRate['USDUSDT'] = 1.0;
    _rateCacheTime['USDUSDT'] = now;
    _pairToRate['USDTUSD'] = 1.0;
    _rateCacheTime['USDTUSD'] = now;

    // Emit initial rates
    _controller.add(Map<String, double>.from(_pairToRate));

    // Start periodic refresh every 5 minutes
    _refreshTimer = Timer.periodic(_cacheDuration, (_) => _refreshAllRates());
  }

  Stream<Map<String, double>> get ratesStream => _controller.stream;

  /// Exchange quote: `GET /customer-rates?send={send}&get={get}`.
  ///
  /// Uses `data.rate` (or `data.exchangeRate`) for Get preview.
  /// Does **not** default to 1.0 on failure — throws [ExchangeQuoteException].
  Future<ExchangeQuote> fetchExchangeQuote({
    required String send,
    required String get,
  }) async {
    final sendCode = send.trim().toUpperCase();
    final getCode = get.trim().toUpperCase();

    if (sendCode.isEmpty || getCode.isEmpty) {
      throw const ExchangeQuoteException(
        statusCode: 400,
        message: 'Send and Get assets are required.',
      );
    }
    if (sendCode == getCode) {
      throw const ExchangeQuoteException(
        statusCode: 400,
        message: 'Choose two different assets to exchange.',
      );
    }

    final url = Uri.parse('$_baseUrl/customer-rates').replace(
      queryParameters: {
        'send': sendCode,
        'get': getCode,
      },
    );

    Logger.debug('📡 EXCHANGE QUOTE API REQUEST');
    Logger.debug('  Method: GET');
    Logger.debug('  URL: $url');
    Logger.debug('  Query Parameters: send=$sendCode, get=$getCode');

    late final http.Response response;
    try {
      response = await http.get(url);
    } catch (e, st) {
      Logger.error('Exchange quote network error', e, st);
      throw const ExchangeQuoteException(
        statusCode: 0,
        message: 'Could not load exchange rate. Check your connection.',
      );
    }

    _logRawHttpResponse('EXCHANGE QUOTE API RESPONSE', response);

    if (response.statusCode == 400) {
      throw const ExchangeQuoteException(
        statusCode: 400,
        message: 'Missing send or get asset for this quote.',
      );
    }
    if (response.statusCode == 404) {
      throw const ExchangeQuoteException(
        statusCode: 404,
        message:
            'No rate available for this pair yet. Try a different combination.',
      );
    }
    if (response.statusCode != 200) {
      throw ExchangeQuoteException(
        statusCode: response.statusCode,
        message: 'Could not load exchange rate (${response.statusCode}).',
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = json.decode(response.body) as Map<String, dynamic>;
    } catch (e, st) {
      Logger.error('Exchange quote JSON parse error', e, st);
      throw const ExchangeQuoteException(
        statusCode: 200,
        message: 'Invalid rate response from server.',
      );
    }

    final data = _ratesPayload(decoded);
    lastCustomerRatesPayload = Map<String, dynamic>.from(data);
    Logger.debug('  Rates payload: $data');

    final rate = (data['rate'] as num?)?.toDouble() ??
        (data['exchangeRate'] as num?)?.toDouble();
    if (rate == null || rate <= 0) {
      throw const ExchangeQuoteException(
        statusCode: 200,
        message: 'Rate missing from server response.',
      );
    }

    final display = (data['display'] as String?)?.trim().isNotEmpty == true
        ? (data['display'] as String).trim()
        : '1 $sendCode = ${rate.toStringAsFixed(4)} $getCode';

    final cacheKey = '$sendCode$getCode';
    _pairToRate[cacheKey] = rate;
    _rateCacheTime[cacheKey] = DateTime.now();
    _notifyRates();

    Logger.success(
      'Exchange quote: send=$sendCode get=$getCode rate=$rate display=$display',
    );

    return ExchangeQuote(
      send: sendCode,
      get: getCode,
      rate: rate,
      display: display,
      raw: data,
    );
  }

  /// Stablecoins share the USDT customer/binance rate endpoints.
  bool _isUsdStable(String currency) {
    final c = currency.toUpperCase();
    return c == 'USDT' || c == 'USDC';
  }

  /// Unwrap `{ success, data: {...} }` envelopes; otherwise return the root map.
  Map<String, dynamic> _ratesPayload(Map<String, dynamic> decoded) {
    final nested = decoded['data'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return decoded;
  }

  /// Log an HTTP response in full (debugPrint truncates ~800 chars).
  void _logRawHttpResponse(String label, http.Response response) {
    final body = response.body;
    Logger.debug('📥 $label');
    Logger.debug('  Status Code: ${response.statusCode}');
    Logger.debug('  Headers: ${response.headers}');
    Logger.debug('  Raw Response Body length: ${body.length}');
    if (body.isEmpty) {
      Logger.debug('  Raw Response Body: <empty>');
      return;
    }
    // Chunk so the full body always appears in the console.
    const chunkSize = 800;
    for (var i = 0; i < body.length; i += chunkSize) {
      final end = (i + chunkSize < body.length) ? i + chunkSize : body.length;
      final part = body.substring(i, end);
      final chunkIndex = (i ~/ chunkSize) + 1;
      final chunkCount = ((body.length - 1) ~/ chunkSize) + 1;
      Logger.debug('  Raw Response Body [$chunkIndex/$chunkCount]: $part');
    }
  }

  /// Get exchange rate for a currency pair
  /// Uses customer rates (buyRate/sellRate) when available for customer-facing transactions
  /// Returns cached rate immediately, triggers background refresh if stale
  ///
  /// For USDT/fiat pairs:
  /// - When converting fiat -> USDT (buying USDT), uses buyRate
  /// - When converting USDT -> fiat (selling USDT), uses sellRate
  /// Read-only rate lookup. Must never emit on [ratesStream] — callers listen
  /// to that stream and would otherwise create an infinite setState loop.
  double getRate(String base, String quote) {
    final key = (base + quote).toUpperCase();
    final baseUpper = base.toUpperCase();
    final quoteUpper = quote.toUpperCase();

    // USD ↔ USDT/USDC is always 1:1 (API USDT/USD often returns a wrong fiat rate).
    if ((baseUpper == 'USD' && _isUsdStable(quoteUpper)) ||
        (_isUsdStable(baseUpper) && quoteUpper == 'USD') ||
        (_isUsdStable(baseUpper) && _isUsdStable(quoteUpper))) {
      return 1.0;
    }

    // Check if this is a USDT/USDC/fiat pair that can use customer rates
    String? currencyPair;
    bool isBuyingUSDT = false; // true if fiat -> stable, false if stable -> fiat

    if (_isUsdStable(baseUpper) && quoteUpper != 'USD') {
      currencyPair = 'USDT/$quoteUpper';
      isBuyingUSDT = false; // Selling stable for fiat
    } else if (_isUsdStable(quoteUpper) && baseUpper != 'USD') {
      currencyPair = 'USDT/$baseUpper';
      isBuyingUSDT = true; // Buying stable with fiat
    }

    // Try to use customer rates first if available (read-only — no stream emit).
    if (currencyPair != null) {
      final customerRates = _getCustomerRatesFromCache(currencyPair);
      if (customerRates != null) {
        return isBuyingUSDT
            ? 1.0 / customerRates.buyRate // fiat -> USDT: inverse of buyRate
            : customerRates.sellRate; // USDT -> fiat: use sellRate directly
      } else {
        // Trigger fetch of customer rates (fire and forget, but will update cache)
        _fetchCustomerRates(currencyPair).catchError((e) {
          Logger.error('Error in background customer rates fetch', e);
        });
      }
    }

    // Check cache first
    if (_pairToRate.containsKey(key)) {
      final cacheTime = _rateCacheTime[key];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _cacheDuration) {
        return _pairToRate[key]!;
      } else {
        // Cache is stale, trigger background refresh
        _fetchRate(base, quote).catchError((e) {
          Logger.error('Error in background rate fetch', e);
        });
      }
    } else {
      // No cache - for fiat-to-fiat try composed rate from legs (same API as Send Money)
      if (baseUpper != quoteUpper &&
          _isFiat(baseUpper) &&
          _isFiat(quoteUpper)) {
        final r1 = _pairToRate['${baseUpper}USDT'] ??
            _pairToRate['${baseUpper}USDC'];
        final r2 = _pairToRate['USDT$quoteUpper'] ??
            _pairToRate['USDC$quoteUpper'];
        if (r1 != null && r2 != null && r1 > 0 && r2 > 0) {
          return r1 * r2;
        }
      }
      // Trigger fetch
      _fetchRate(base, quote).catchError((e) {
        Logger.error('Error in background rate fetch', e);
      });
    }

    // Return cached rate or default
    return _pairToRate[key] ?? 1.0;
  }

  /// Cached customer rates for a pair like `USDT/ETB`, if still fresh.
  CustomerRates? getCustomerRates(String currencyPair) =>
      _getCustomerRatesFromCache(currencyPair);

  /// Get customer rates (buyRate and sellRate) for a currency pair
  /// Returns null if not available or cache is stale
  CustomerRates? _getCustomerRatesFromCache(String currencyPair) {
    final cacheTime = _customerRatesCacheTime[currencyPair];
    if (cacheTime != null &&
        DateTime.now().difference(cacheTime) < _cacheDuration) {
      return _customerRatesCache[currencyPair];
    }
    return null;
  }

  /// Fetch customer rates from /api/customer-rates endpoint
  /// Format: GET /api/customer-rates?currencyPair=USDT/KES
  /// Returns either:
  /// - `{ "buyRate": 129.50, "sellRate": 128.00 }`
  /// - `{ "success": true, "data": { "buyRate": ..., "sellRate": ... } }`
  Future<void> _fetchCustomerRates(String currencyPair) async {
    try {
      final url =
          Uri.parse('$_baseUrl/customer-rates?currencyPair=$currencyPair');

      Logger.debug('📡 CUSTOMER RATES API REQUEST');
      Logger.debug('  Method: GET');
      Logger.debug('  URL: $url');
      Logger.debug('  Headers: {}');
      Logger.debug('  Query Parameters: currencyPair=$currencyPair');

      final response = await http.get(url);
      _logRawHttpResponse('CUSTOMER RATES API RESPONSE', response);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final ratesPayload = _ratesPayload(decoded);

        Logger.debug('  Parsed Response: $decoded');
        Logger.debug('  Rates payload: $ratesPayload');

        final buyRate = (ratesPayload['buyRate'] as num?)?.toDouble();
        final sellRate = (ratesPayload['sellRate'] as num?)?.toDouble();

        if (buyRate != null && sellRate != null) {
          Logger.success(
              'Customer rates fetched: buyRate=$buyRate, sellRate=$sellRate');

          lastCustomerRatesPayload = Map<String, dynamic>.from(ratesPayload);

          _customerRatesCache[currencyPair] = CustomerRates(
            buyRate: buyRate,
            sellRate: sellRate,
          );
          _customerRatesCacheTime[currencyPair] = DateTime.now();

          // Update the rate cache based on the currency pair direction
          // Parse currency pair (e.g., "USDT/KES")
          final parts = currencyPair.split('/');
          if (parts.length == 2) {
            final base = parts[0];
            final quote = parts[1];

            // Batch cache writes, then notify listeners once.
            _updateRate(base, quote, sellRate, notify: false);
            _updateRate(quote, base, 1.0 / buyRate, notify: false);
            // Mirror onto USDC so ETB/USDC etc. resolve the same rates.
            if (base.toUpperCase() == 'USDT') {
              _updateRate('USDC', quote, sellRate, notify: false);
              _updateRate(quote, 'USDC', 1.0 / buyRate, notify: false);
            }
            _notifyRates();
          }
        } else {
          Logger.warning('Customer rates response missing buyRate or sellRate');
        }
      } else {
        Logger.error(
            'Customer rates API returned non-200 status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      Logger.error(
          'Error fetching customer rates for $currencyPair', e, stackTrace);
      // Fall back to binance rates if customer rates fail
    }
  }

  /// Get buy rate for a currency pair (when buying USDT with fiat)
  /// Example: getBuyRate('KES', 'USDT') returns the rate for KES -> USDT
  Future<double?> getBuyRate(String fiat, String asset) async {
    final currencyPair = '$asset/$fiat';
    final cached = _getCustomerRatesFromCache(currencyPair);

    if (cached != null) {
      return cached.buyRate;
    }

    // Fetch if not cached
    await _fetchCustomerRates(currencyPair);
    final updated = _getCustomerRatesFromCache(currencyPair);
    return updated?.buyRate;
  }

  /// Get sell rate for a currency pair (when selling USDT for fiat)
  /// Example: getSellRate('USDT', 'KES') returns the rate for USDT -> KES
  Future<double?> getSellRate(String asset, String fiat) async {
    final currencyPair = '$asset/$fiat';
    final cached = _getCustomerRatesFromCache(currencyPair);

    if (cached != null) {
      return cached.sellRate;
    }

    // Fetch if not cached
    await _fetchCustomerRates(currencyPair);
    final updated = _getCustomerRatesFromCache(currencyPair);
    return updated?.sellRate;
  }

  /// True if currency is a supported fiat (used for fiat-to-fiat rate via USDT).
  bool _isFiat(String currency) {
    final c = currency.toUpperCase();
    return c == 'USD' || _isSupportedFiat(c);
  }

  /// Fetch rate from API for a specific currency pair
  /// Falls back to Binance rates if customer rates are not available
  Future<void> _fetchRate(String base, String quote) async {
    try {
      final baseUpper = base.toUpperCase();
      final quoteUpper = quote.toUpperCase();

      // Fiat-to-fiat (e.g. USD/KES): compute via USDT using same API as Send Money
      if (baseUpper != quoteUpper &&
          _isFiat(baseUpper) &&
          _isFiat(quoteUpper)) {
        Logger.debug(
            '🔄 Fetching fiat-to-fiat rate $baseUpper/$quoteUpper via USDT');
        await _fetchRate(base, 'USDT');
        await _fetchRate('USDT', quote);
        final key1 = ('${baseUpper}USDT');
        final key2 = ('USDT$quoteUpper');
        final r1 = _pairToRate[key1];
        final r2 = _pairToRate[key2];
        if (r1 != null && r2 != null && r1 > 0 && r2 > 0) {
          final rate = r1 * r2;
          Logger.debug(
              '✅ Fiat-to-fiat rate $baseUpper/$quoteUpper = $rate (via USDT)');
          _updateRate(base, quote, rate);
          _updateRate(quote, base, 1.0 / rate);
        }
        return;
      }

      // USD ↔ USDT/USDC (and USDT ↔ USDC) is always 1:1.
      // Do not call customer-rates for USDT/USD — that pair often returns a
      // mislabeled local-fiat rate (e.g. ~130) which freezes/wrong-rates UI.
      if ((baseUpper == 'USD' && _isUsdStable(quoteUpper)) ||
          (_isUsdStable(baseUpper) && quoteUpper == 'USD') ||
          (_isUsdStable(baseUpper) && _isUsdStable(quoteUpper))) {
        Logger.debug('Using 1:1 rate for $baseUpper/$quoteUpper');
        lastCustomerRatesPayload = {
          'currencyPair': '$baseUpper/$quoteUpper',
          'buyRate': 1.0,
          'sellRate': 1.0,
          'source': 'peg',
        };
        _updateRate(base, quote, 1.0, notify: false);
        _updateRate(quote, base, 1.0, notify: false);
        _notifyRates();
        return;
      }

      // For USDT|USDC/fiat pairs, try customer rates first, then fall back to Binance
      String? fiat;
      const asset = 'USDT'; // API asset key; USDC uses the same endpoints
      bool isBaseStable = false;

      if (_isUsdStable(baseUpper)) {
        fiat = quoteUpper;
        isBaseStable = true;
      } else if (_isUsdStable(quoteUpper)) {
        fiat = baseUpper;
        isBaseStable = false;
      }

      // Call the rates API for any fiat (including ones outside the hard-coded list)
      // so the raw response is always visible while debugging.
      if (fiat != null && fiat != 'USD') {
        if (!_isSupportedFiat(fiat)) {
          Logger.debug(
              '⚠️ Fiat $fiat is outside the known supported list; still calling rates API');
        }

        // Try customer rates first
        final currencyPair = '$asset/$fiat';
        await _fetchCustomerRates(currencyPair);

        // Check if customer rates were successfully fetched
        final customerRates = _getCustomerRatesFromCache(currencyPair);
        if (customerRates != null) {
          // Use customer rates
          if (isBaseStable) {
            // stable -> Fiat: use sellRate
            _updateRate(base, quote, customerRates.sellRate);
            // Fiat -> stable: inverse of buyRate
            _updateRate(quote, base, 1.0 / customerRates.buyRate);
          } else {
            // Fiat -> stable: inverse of buyRate
            _updateRate(base, quote, 1.0 / customerRates.buyRate);
            // stable -> Fiat: use sellRate
            _updateRate(quote, base, customerRates.sellRate);
          }
          return;
        }

        // Fall back to Binance rates if customer rates are not available
        final url =
            Uri.parse('$_baseUrl/binance/rates?fiat=$fiat&asset=$asset');

        Logger.debug('📡 BINANCE RATES API REQUEST');
        Logger.debug('  Method: GET');
        Logger.debug('  URL: $url');
        Logger.debug('  Headers: {}');
        Logger.debug('  Query Parameters: fiat=$fiat, asset=$asset');

        final response = await http.get(url);
        _logRawHttpResponse('BINANCE RATES API RESPONSE', response);

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body) as Map<String, dynamic>;
          final data = _ratesPayload(decoded);

          Logger.debug('  Parsed Response: $decoded');
          Logger.debug('  Rates payload: $data');

          // Use customerPrice (rate with commission) - this is the rate we should use for transactions
          // customerPrice is the rate WITH commission already applied
          final customerPrice = (data['customerPrice'] as num?)?.toDouble();

          if (customerPrice != null) {
            Logger.success(
                'Binance rate fetched: customerPrice=$customerPrice');

            // customerPrice represents: 1 USDT = customerPrice fiat
            // Store the rate in the correct direction
            if (isBaseStable) {
              // stable -> Fiat: use customerPrice directly
              _updateRate(base, quote, customerPrice);
              // Fiat -> stable: inverse
              _updateRate(quote, base, 1.0 / customerPrice);
            } else {
              // Fiat -> stable: inverse of customerPrice
              _updateRate(base, quote, 1.0 / customerPrice);
              // stable -> Fiat: use customerPrice directly
              _updateRate(quote, base, customerPrice);
            }
          } else {
            Logger.warning('Binance rates response missing customerPrice');
          }
        } else {
          Logger.error(
              'Binance rates API returned non-200 status: ${response.statusCode}');
          Logger.debug(
              'Using default 1.0 for $baseUpper/$quoteUpper after non-200 rates response');
          _updateRate(base, quote, 1.0);
          _updateRate(quote, base, 1.0);
        }
      } else if (fiat == 'USD') {
        // USD/USDT is 1:1
        _updateRate(base, quote, 1.0);
        _updateRate(quote, base, 1.0);
      } else {
        Logger.debug(
            '⚠️ No rate API path for $baseUpper/$quoteUpper — defaulting to 1.0');
        _updateRate(base, quote, 1.0);
        _updateRate(quote, base, 1.0);
      }
    } catch (e, stackTrace) {
      Logger.error('Error fetching rate for $base/$quote', e, stackTrace);
      // Keep existing cached rate if available
    }
  }

  /// Check if a currency is a supported fiat currency
  bool _isSupportedFiat(String currency) {
    const supportedFiats = [
      'KES',
      'NGN',
      'GHS',
      'USD',
      'ETB',
      'UGX',
      'TZS',
      'ZAR',
      'BIF',
    ];
    return supportedFiats.contains(currency.toUpperCase());
  }

  /// Update rate in cache. Set [notify] false to batch multiple writes.
  void _updateRate(
    String base,
    String quote,
    double rate, {
    bool notify = true,
  }) {
    final key = (base + quote).toUpperCase();
    final previous = _pairToRate[key];
    if (previous != null && (previous - rate).abs() < 1e-12) {
      _rateCacheTime[key] = DateTime.now();
      return;
    }
    _pairToRate[key] = rate;
    _rateCacheTime[key] = DateTime.now();
    if (notify) _notifyRates();
  }

  void _notifyRates() {
    if (_controller.isClosed) return;
    _controller.add(Map<String, double>.from(_pairToRate));
  }

  /// Refresh all cached rates
  Future<void> _refreshAllRates() async {
    // Refresh customer rates
    final customerPairs = _customerRatesCache.keys.toList();
    for (final pair in customerPairs) {
      await _fetchCustomerRates(pair);
    }

    // Refresh regular rates
    final pairs = _pairToRate.keys.toList();
    for (final key in pairs) {
      if (key.length >= 6) {
        final base = key.substring(0, 3);
        final quote = key.substring(3);
        await _fetchRate(base, quote);
      }
    }
  }

  /// Manually refresh a specific rate
  Future<void> refreshRate(String base, String quote) async {
    Logger.debug('🔄 Refreshing rate for $base/$quote');
    // Clear cache to force fresh fetch
    final key = (base + quote).toUpperCase();
    _pairToRate.remove(key);
    _rateCacheTime.remove(key);

    // Also clear customer rates cache for this pair
    final baseUpper = base.toUpperCase();
    final quoteUpper = quote.toUpperCase();
    String? currencyPair;
    if ((baseUpper == 'USD' && _isUsdStable(quoteUpper)) ||
        (_isUsdStable(baseUpper) && quoteUpper == 'USD') ||
        (_isUsdStable(baseUpper) && _isUsdStable(quoteUpper))) {
      // Pegged — no customer-rates pair to clear.
      currencyPair = null;
    } else if (_isUsdStable(baseUpper) && quoteUpper != 'USD') {
      currencyPair = 'USDT/$quoteUpper';
    } else if (_isUsdStable(quoteUpper) && baseUpper != 'USD') {
      currencyPair = 'USDT/$baseUpper';
    }
    if (currencyPair != null) {
      _customerRatesCache.remove(currencyPair);
      _customerRatesCacheTime.remove(currencyPair);
    }

    // Now fetch fresh rate
    await _fetchRate(base, quote);
  }

  void dispose() {
    _refreshTimer?.cancel();
    _controller.close();
  }
}
