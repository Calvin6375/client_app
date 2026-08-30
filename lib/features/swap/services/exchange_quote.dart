/// Quote returned by `GET /customer-rates?send=&get=` for Exchange.
class ExchangeQuote {
  const ExchangeQuote({
    required this.send,
    required this.get,
    required this.rate,
    required this.display,
    required this.raw,
  });

  final String send;
  final String get;

  /// Multiply Send amount by this to get Get amount: `getAmount = sendAmount * rate`.
  final double rate;

  /// Preferred UI label, e.g. `1 ETB = 0.0110 USDC`.
  final String display;

  /// Full `data` object from the API (stored in UI state).
  final Map<String, dynamic> raw;

  double getAmount(double sendAmount) => sendAmount * rate;
}

/// Failed Exchange quote fetch (400 / 404 / missing rate / network).
class ExchangeQuoteException implements Exception {
  const ExchangeQuoteException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() => 'ExchangeQuoteException($statusCode): $message';
}
