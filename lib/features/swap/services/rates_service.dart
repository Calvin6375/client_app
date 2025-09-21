import 'dart:async';

/// Simple placeholder rate service with a stream API so UI can reactively update
class RatesService {
  // Simulated backing store (could be replaced with HTTP or Firebase)
  final Map<String, double> _pairToRate = {
    'NGNUSD': 740.0, // NGN per 1 USD
    'USDNGN': 1 / 740.0, // USD per 1 NGN
    'KESNGN': 1 / 12.0, // KES per 1 NGN
    'NGNKES': 120.0, // NGN per 1 KES
  };

  final StreamController<Map<String, double>> _controller = StreamController.broadcast();

  RatesService() {
    // Emit initial
    _controller.add(Map<String, double>.from(_pairToRate));
  }

  Stream<Map<String, double>> get ratesStream => _controller.stream;

  double getRate(String base, String quote) {
    final key = (base + quote).toUpperCase();
    return _pairToRate[key] ?? 740.0;
  }

  // Simulate a live update (callable from UI for demo)
  void simulateUpdate(String base, String quote, double newRate) {
    final key = (base + quote).toUpperCase();
    _pairToRate[key] = newRate;
    // Keep inverse coherent if pair is NGNUSD/ USDNGN
    if (key == 'NGNUSD') {
      _pairToRate['USDNGN'] = 1 / newRate;
    } else if (key == 'USDNGN') {
      _pairToRate['NGNUSD'] = 1 / newRate;
    }
    _controller.add(Map<String, double>.from(_pairToRate));
  }

  void dispose() {
    _controller.close();
  }
}