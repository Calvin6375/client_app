import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pretium/utils/logger.dart';

/// Customer rates model for buy/sell rates
class CustomerRates {
  final double buyRate;  // Rate when buying USDT with fiat
  final double sellRate; // Rate when selling USDT for fiat
  
  CustomerRates({required this.buyRate, required this.sellRate});
}

/// Rate service that fetches exchange rates from the backend API
/// Uses customer rates (buyRate/sellRate) from /api/customer-rates endpoint for customer transactions
/// Falls back to /api/binance/rates for reference rates
class RatesService {
  // Base URL for the backend API
  static const String _baseUrl = 'https://us-central1-truepay-72060.cloudfunctions.net/api';
  
  // Cache for rates to avoid excessive API calls
  final Map<String, double> _pairToRate = {};
  final Map<String, DateTime> _rateCacheTime = {};
  
  // Cache for customer rates (buyRate/sellRate)
  final Map<String, CustomerRates> _customerRatesCache = {};
  final Map<String, DateTime> _customerRatesCacheTime = {};
  
  // Cache duration: 5 minutes (rates are valid for 5-10 minutes per API docs)
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  final StreamController<Map<String, double>> _controller = StreamController.broadcast();
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

  /// Get exchange rate for a currency pair
  /// Uses customer rates (buyRate/sellRate) when available for customer-facing transactions
  /// Returns cached rate immediately, triggers background refresh if stale
  /// 
  /// For USDT/fiat pairs:
  /// - When converting fiat -> USDT (buying USDT), uses buyRate
  /// - When converting USDT -> fiat (selling USDT), uses sellRate
  double getRate(String base, String quote) {
    final key = (base + quote).toUpperCase();
    final baseUpper = base.toUpperCase();
    final quoteUpper = quote.toUpperCase();
    
    // Check if this is a USDT/fiat pair that can use customer rates
    String? currencyPair;
    bool isBuyingUSDT = false; // true if fiat -> USDT, false if USDT -> fiat
    
    // Handle USD/USDT pair - still try to fetch rates from API
    if ((baseUpper == 'USD' && quoteUpper == 'USDT') ||
        (baseUpper == 'USDT' && quoteUpper == 'USD')) {
      currencyPair = 'USDT/USD';
      isBuyingUSDT = baseUpper == 'USD'; // USD -> USDT is buying USDT
    } else if (baseUpper == 'USDT' && quoteUpper != 'USD') {
      currencyPair = '$baseUpper/$quoteUpper';
      isBuyingUSDT = false; // Selling USDT for fiat
    } else if (quoteUpper == 'USDT' && baseUpper != 'USD') {
      currencyPair = '$quoteUpper/$baseUpper';
      isBuyingUSDT = true; // Buying USDT with fiat
    }
    
    // Try to use customer rates first if available
    if (currencyPair != null) {
      final customerRates = _getCustomerRatesFromCache(currencyPair);
      if (customerRates != null) {
        // Use appropriate rate based on direction
        final rate = isBuyingUSDT 
            ? 1.0 / customerRates.buyRate  // fiat -> USDT: inverse of buyRate
            : customerRates.sellRate;      // USDT -> fiat: use sellRate directly
        _updateRate(base, quote, rate);
        // Also update inverse
        _updateRate(quote, base, 1.0 / rate);
        return rate;
      } else {
        // Trigger fetch of customer rates (fire and forget, but will update cache)
        // Note: This is async but we don't await to avoid blocking
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
      // No cache, trigger fetch
      _fetchRate(base, quote).catchError((e) {
        Logger.error('Error in background rate fetch', e);
      });
    }
    
    // Return cached rate or default
    return _pairToRate[key] ?? 1.0;
  }
  
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
  /// Returns: { "buyRate": 129.50, "sellRate": 128.00 }
  Future<void> _fetchCustomerRates(String currencyPair) async {
    try {
      final url = Uri.parse('$_baseUrl/customer-rates?currencyPair=$currencyPair');
      
      // Log raw request
      Logger.debug('📡 CUSTOMER RATES API REQUEST');
      Logger.debug('  Method: GET');
      Logger.debug('  URL: $url');
      Logger.debug('  Headers: {}');
      Logger.debug('  Query Parameters: currencyPair=$currencyPair');
      
      final response = await http.get(url);
      
      // Log raw response
      Logger.debug('📥 CUSTOMER RATES API RESPONSE');
      Logger.debug('  Status Code: ${response.statusCode}');
      Logger.debug('  Headers: ${response.headers}');
      Logger.debug('  Raw Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        Logger.debug('  Parsed Response: $data');
        
        final buyRate = (data['buyRate'] as num?)?.toDouble();
        final sellRate = (data['sellRate'] as num?)?.toDouble();
        
        if (buyRate != null && sellRate != null) {
          Logger.success('Customer rates fetched: buyRate=$buyRate, sellRate=$sellRate');
          
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
            
            // USDT -> Fiat: use sellRate
            _updateRate(base, quote, sellRate);
            // Fiat -> USDT: inverse of buyRate
            _updateRate(quote, base, 1.0 / buyRate);
          }
        } else {
          Logger.warning('Customer rates response missing buyRate or sellRate');
        }
      } else {
        Logger.error('Customer rates API returned non-200 status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      Logger.error('Error fetching customer rates for $currencyPair', e, stackTrace);
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

  /// Fetch rate from API for a specific currency pair
  /// Falls back to Binance rates if customer rates are not available
  Future<void> _fetchRate(String base, String quote) async {
    try {
      final baseUpper = base.toUpperCase();
      final quoteUpper = quote.toUpperCase();
      
      // Handle USD/USDT pair - try to fetch from API first, then default to 1.0
      if ((baseUpper == 'USD' && quoteUpper == 'USDT') ||
          (baseUpper == 'USDT' && quoteUpper == 'USD')) {
        // Try customer rates first for USD/USDT
        final currencyPair = 'USDT/USD';
        await _fetchCustomerRates(currencyPair);
        
        final customerRates = _getCustomerRatesFromCache(currencyPair);
        if (customerRates != null) {
          // Use customer rates if available
          final rate = baseUpper == 'USD' 
              ? 1.0 / customerRates.buyRate  // USD -> USDT: inverse of buyRate
              : customerRates.sellRate;     // USDT -> USD: use sellRate
          _updateRate(base, quote, rate);
          _updateRate(quote, base, 1.0 / rate);
          return;
        }
        
        // Fall back to Binance rates for USD/USDT
        final url = Uri.parse('$_baseUrl/binance/rates?fiat=USD&asset=USDT');
        
        Logger.debug('📡 BINANCE RATES API REQUEST (USD/USDT)');
        Logger.debug('  Method: GET');
        Logger.debug('  URL: $url');
        Logger.debug('  Headers: {}');
        Logger.debug('  Query Parameters: fiat=USD, asset=USDT');
        
        final response = await http.get(url);
        
        Logger.debug('📥 BINANCE RATES API RESPONSE (USD/USDT)');
        Logger.debug('  Status Code: ${response.statusCode}');
        Logger.debug('  Headers: ${response.headers}');
        Logger.debug('  Raw Response Body: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          Logger.debug('  Parsed Response: $data');
          
          final customerPrice = (data['customerPrice'] as num?)?.toDouble();
          if (customerPrice != null && customerPrice > 0) {
            Logger.success('Binance rate fetched for USD/USDT: customerPrice=$customerPrice');
            final rate = baseUpper == 'USD' ? 1.0 / customerPrice : customerPrice;
            _updateRate(base, quote, rate);
            _updateRate(quote, base, 1.0 / rate);
            return;
          }
        }
        
        // Default to 1.0 if API calls fail
        Logger.debug('Using default 1.0 rate for USD/USDT (API unavailable or returned invalid data)');
        _updateRate(base, quote, 1.0);
        _updateRate(quote, base, 1.0);
        return;
      }
      
      // For USDT/fiat pairs, try customer rates first, then fall back to Binance
      String? fiat;
      String asset = 'USDT';
      bool isBaseUSDT = false;
      
      if (baseUpper == 'USDT') {
        fiat = quoteUpper;
        isBaseUSDT = true;
      } else if (quoteUpper == 'USDT') {
        fiat = baseUpper;
        isBaseUSDT = false;
      }
      
      // If it's a fiat currency supported by the API (excluding USD which is 1:1 with USDT)
      if (fiat != null && fiat != 'USD' && _isSupportedFiat(fiat)) {
        // Try customer rates first
        final currencyPair = '$asset/$fiat';
        await _fetchCustomerRates(currencyPair);
        
        // Check if customer rates were successfully fetched
        final customerRates = _getCustomerRatesFromCache(currencyPair);
        if (customerRates != null) {
          // Use customer rates
          if (isBaseUSDT) {
            // USDT -> Fiat: use sellRate
            _updateRate(base, quote, customerRates.sellRate);
            // Fiat -> USDT: inverse of buyRate
            _updateRate(quote, base, 1.0 / customerRates.buyRate);
          } else {
            // Fiat -> USDT: inverse of buyRate
            _updateRate(base, quote, 1.0 / customerRates.buyRate);
            // USDT -> Fiat: use sellRate
            _updateRate(quote, base, customerRates.sellRate);
          }
          return;
        }
        
        // Fall back to Binance rates if customer rates are not available
        final url = Uri.parse('$_baseUrl/binance/rates?fiat=$fiat&asset=$asset');
        
        // Log raw request
        Logger.debug('📡 BINANCE RATES API REQUEST');
        Logger.debug('  Method: GET');
        Logger.debug('  URL: $url');
        Logger.debug('  Headers: {}');
        Logger.debug('  Query Parameters: fiat=$fiat, asset=$asset');
        
        final response = await http.get(url);
        
        // Log raw response
        Logger.debug('📥 BINANCE RATES API RESPONSE');
        Logger.debug('  Status Code: ${response.statusCode}');
        Logger.debug('  Headers: ${response.headers}');
        Logger.debug('  Raw Response Body: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          
          Logger.debug('  Parsed Response: $data');
          
          // Use customerPrice (rate with commission) - this is the rate we should use for transactions
          // customerPrice is the rate WITH commission already applied
          final customerPrice = (data['customerPrice'] as num?)?.toDouble();
          
          if (customerPrice != null) {
            Logger.success('Binance rate fetched: customerPrice=$customerPrice');
            
            // customerPrice represents: 1 USDT = customerPrice fiat
            // Store the rate in the correct direction
            if (isBaseUSDT) {
              // USDT -> Fiat: use customerPrice directly
              _updateRate(base, quote, customerPrice);
              // Fiat -> USDT: inverse
              _updateRate(quote, base, 1.0 / customerPrice);
            } else {
              // Fiat -> USDT: inverse of customerPrice
              _updateRate(base, quote, 1.0 / customerPrice);
              // USDT -> Fiat: use customerPrice directly
              _updateRate(quote, base, customerPrice);
            }
          } else {
            Logger.warning('Binance rates response missing customerPrice');
          }
        } else {
          Logger.error('Binance rates API returned non-200 status: ${response.statusCode}');
        }
      } else if (fiat == 'USD') {
        // USD/USDT is 1:1
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
    const supportedFiats = ['KES', 'NGN', 'GHS', 'USD'];
    return supportedFiats.contains(currency.toUpperCase());
  }

  /// Update rate in cache and notify listeners
  void _updateRate(String base, String quote, double rate) {
    final key = (base + quote).toUpperCase();
    _pairToRate[key] = rate;
    _rateCacheTime[key] = DateTime.now();
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
    if ((baseUpper == 'USD' && quoteUpper == 'USDT') ||
        (baseUpper == 'USDT' && quoteUpper == 'USD')) {
      currencyPair = 'USDT/USD';
    } else if (baseUpper == 'USDT' && quoteUpper != 'USD') {
      currencyPair = '$baseUpper/$quoteUpper';
    } else if (quoteUpper == 'USDT' && baseUpper != 'USD') {
      currencyPair = '$quoteUpper/$baseUpper';
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