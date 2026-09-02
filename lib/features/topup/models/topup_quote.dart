/// Response from `POST /funding/topup/quote` (quote only — no payment created).
class TopupQuote {
  const TopupQuote({
    required this.youDeposit,
    required this.processingFees,
    required this.paymentMethodFees,
    required this.youWillPay,
    required this.checkoutProvider,
    this.currency,
    this.amount,
  });

  /// Display string for "You deposit" (e.g. `180.00 KES`).
  final String youDeposit;

  /// Display string for "Processing fees" (`Free` or `4.50 KES`).
  final String processingFees;

  /// Display string for "Payment method fees" (always `Free` for now).
  final String paymentMethodFees;

  /// Display string for "You will pay" (e.g. `184.50 KES`).
  final String youWillPay;

  /// Checkout provider label (e.g. `Paystack`).
  final String checkoutProvider;

  final String? currency;
  final double? amount;

  factory TopupQuote.fromJson(Map<String, dynamic> json) {
    final currency = _stringOrNull(json['currency'])?.toUpperCase();
    final amount = _asDouble(json['amount'] ?? json['depositAmount']);

    final lines = json['lines'];
    Map<String, dynamic>? linesMap;
    if (lines is Map) {
      linesMap = Map<String, dynamic>.from(lines);
    }

    final processingFromLine = _lineDisplay(linesMap, const [
      'processing_fees',
      'processingFees',
      'processing',
    ]);
    final paymentMethodFromLine = _lineDisplay(linesMap, const [
      'payment_method_fees',
      'paymentMethodFees',
      'payment_method',
    ]);
    final youDepositFromLine = _lineDisplay(linesMap, const [
      'you_deposit',
      'youDeposit',
      'deposit',
    ]);
    final youWillPayFromLine = _lineDisplay(linesMap, const [
      'you_will_pay',
      'youWillPay',
      'total',
      'paystack_amount',
    ]);

    final youDeposit = _display(
      json['youDeposit'] ?? json['you_deposit'] ?? youDepositFromLine,
      fallbackAmount: amount,
      currency: currency,
      fallbackLabel: amount != null && currency != null
          ? _formatAmount(amount, currency)
          : '—',
    );

    final processingFees = _display(
      json['processingFees'] ??
          json['processing_fees'] ??
          processingFromLine,
      fallbackLabel: 'Free',
    );

    final paymentMethodFees = _display(
      json['paymentMethodFees'] ??
          json['payment_method_fees'] ??
          paymentMethodFromLine,
      fallbackLabel: 'Free',
    );

    final youWillPay = _display(
      json['youWillPay'] ??
          json['you_will_pay'] ??
          json['paystackAmount'] ??
          json['paystack_amount'] ??
          youWillPayFromLine,
      fallbackAmount: amount,
      currency: currency,
      fallbackLabel: amount != null && currency != null
          ? _formatAmount(amount, currency)
          : youDeposit,
    );

    final checkoutProvider = _display(
      json['checkoutProvider'] ?? json['checkout_provider'],
      fallbackLabel: 'Paystack',
    );

    return TopupQuote(
      youDeposit: youDeposit,
      processingFees: processingFees,
      paymentMethodFees: paymentMethodFees,
      youWillPay: youWillPay,
      checkoutProvider: checkoutProvider,
      currency: currency,
      amount: amount,
    );
  }

  /// Local fallback when the quote API is unavailable.
  factory TopupQuote.fallback({
    required double amount,
    required String currency,
    String checkoutProvider = 'Paystack',
  }) {
    final label = _formatAmount(amount, currency);
    return TopupQuote(
      youDeposit: label,
      processingFees: 'Free',
      paymentMethodFees: 'Free',
      youWillPay: label,
      checkoutProvider: checkoutProvider,
      currency: currency.toUpperCase(),
      amount: amount,
    );
  }

  static String? _lineDisplay(
    Map<String, dynamic>? lines,
    List<String> keys,
  ) {
    if (lines == null) return null;
    for (final key in keys) {
      final raw = lines[key];
      if (raw is Map) {
        final display = raw['display'] ?? raw['label'] ?? raw['value'];
        final text = _stringOrNull(display);
        if (text != null && text.isNotEmpty) return text;
      } else {
        final text = _stringOrNull(raw);
        if (text != null && text.isNotEmpty) return text;
      }
    }
    return null;
  }

  static String _display(
    Object? value, {
    double? fallbackAmount,
    String? currency,
    required String fallbackLabel,
  }) {
    if (value is num) {
      if (currency != null && currency.isNotEmpty) {
        return _formatAmount(value.toDouble(), currency);
      }
      return value.toString();
    }
    final text = _stringOrNull(value);
    if (text != null && text.isNotEmpty) {
      if (text.toLowerCase() == 'free') return 'Free';
      return text;
    }
    if (fallbackAmount != null &&
        currency != null &&
        currency.isNotEmpty) {
      return _formatAmount(fallbackAmount, currency);
    }
    return fallbackLabel;
  }

  static String _formatAmount(double amount, String currency) =>
      '${amount.toStringAsFixed(2)} ${currency.toUpperCase()}';

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', ''));
    return null;
  }
}
