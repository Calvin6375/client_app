import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Rate service that fetches exchange rates from the backend API
/// Uses customerPrice (rate with commission) from /api/binance/rates endpoint
class RatesService {
  // Base URL for the backend API
  static const String _baseUrl = 'https://us-central1-truepay-72060.cloudfunctions.net/api';
  
  // Cache for rates to avoid excessive API calls
  final Map<String, double> _pairToRate = {};
  final Map<String, DateTime> _rateCacheTime = {};
  
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
  /// Returns cached rate immediately, triggers background refresh if stale
  double getRate(String base, String quote) {
    final key = (base + quote).toUpperCase();
    
    // Check cache first
    if (_pairToRate.containsKey(key)) {
      final cacheTime = _rateCacheTime[key];
      if (cacheTime != null && 
          DateTime.now().difference(cacheTime) < _cacheDuration) {
        return _pairToRate[key]!;
      } else {
        // Cache is stale, trigger background refresh
        _fetchRate(base, quote);
      }
    } else {
      // No cache, trigger fetch
      _fetchRate(base, quote);
    }
    
    // Return cached rate or default
    return _pairToRate[key] ?? 1.0;
  }

  /// Fetch rate from API for a specific currency pair
  Future<void> _fetchRate(String base, String quote) async {
    try {
      final baseUpper = base.toUpperCase();
      final quoteUpper = quote.toUpperCase();
      
      // Handle USD/USDT pair (typically 1:1, stablecoin peg)
      if ((baseUpper == 'USD' && quoteUpper == 'USDT') ||
          (baseUpper == 'USDT' && quoteUpper == 'USD')) {
        _updateRate(base, quote, 1.0);
        _updateRate(quote, base, 1.0);
        return;
      }
      
      // For USDT/fiat pairs, call the API
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
        final url = Uri.parse('$_baseUrl/binance/rates?fiat=$fiat&asset=$asset');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          
          // Use customerPrice (rate with commission) - this is the rate we should use for transactions
          // customerPrice is the rate WITH commission already applied
          final customerPrice = (data['customerPrice'] as num?)?.toDouble();
          
          if (customerPrice != null) {
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
          }
        }
      } else if (fiat == 'USD') {
        // USD/USDT is 1:1
        _updateRate(base, quote, 1.0);
        _updateRate(quote, base, 1.0);
      }
    } catch (e) {
      print('Error fetching rate for $base/$quote: $e');
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
    await _fetchRate(base, quote);
  }

  void dispose() {
    _refreshTimer?.cancel();
    _controller.close();
  }
}