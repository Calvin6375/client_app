/// Response from `POST /safari-card/payouts/quote` (quote only — no payout created).
class SafariTapPayoutQuote {
  const SafariTapPayoutQuote({
    required this.youSend,
    required this.youPay,
    required this.artoFees,
    required this.paymentMethodFees,
    required this.youWillPay,
    this.currency,
    this.amount,
  });

  /// Display string for "You send" (Send Money) (e.g. `10.00 KES`).
  final String youSend;

  /// Display string for "You pay" (Buy Goods / Pay Bill). Falls back to [youSend].
  final String youPay;

  /// Display string for fees (`Free` or `15.08 KES`).
  final String artoFees;

  /// Display string for "Payment method fees" (always `Free` for now).
  final String paymentMethodFees;

  /// Display string for "You will pay" (e.g. `25.08 KES`).
  final String youWillPay;

  final String? currency;
  final double? amount;

  factory SafariTapPayoutQuote.fromJson(Map<String, dynamic> json) {
    final currency = _stringOrNull(json['currency'])?.toUpperCase();
    final amount = _asDouble(json['amount'] ?? json['sendAmount']);

    final lines = json['lines'];
    Map<String, dynamic>? linesMap;
    if (lines is Map) {
      linesMap = Map<String, dynamic>.from(lines);
    }

    final youSendFromLine = _lineDisplay(linesMap, const [
      'you_send',
      'youSend',
      'send',
    ]);
    final youPayFromLine = _lineDisplay(linesMap, const [
      'you_pay',
      'youPay',
      'pay',
    ]);
    final artoFromLine = _lineDisplay(linesMap, const [
      'arto_fees',
      'artoFees',
      'arto',
      'fees',
    ]);
    final paymentMethodFromLine = _lineDisplay(linesMap, const [
      'payment_method_fees',
      'paymentMethodFees',
      'payment_method',
    ]);
    final youWillPayFromLine = _lineDisplay(linesMap, const [
      'you_will_pay',
      'youWillPay',
      'total',
    ]);

    final youSend = _display(
      json['youSend'] ?? json['you_send'] ?? youSendFromLine,
      fallbackAmount: amount,
      currency: currency,
      fallbackLabel: amount != null && currency != null
          ? _formatAmount(amount, currency)
          : '—',
    );

    final youPay = _display(
      json['youPay'] ?? json['you_pay'] ?? youPayFromLine ?? youSend,
      fallbackAmount: amount,
      currency: currency,
      fallbackLabel: youSend,
    );

    final artoFees = _display(
      json['artoFees'] ?? json['arto_fees'] ?? artoFromLine,
      fallbackLabel: 'Free',
    );

    final paymentMethodFees = _display(
      json['paymentMethodFees'] ??
          json['payment_method_fees'] ??
          paymentMethodFromLine,
      fallbackLabel: 'Free',
    );

    final youWillPay = _display(
      json['youWillPay'] ?? json['you_will_pay'] ?? youWillPayFromLine,
      fallbackAmount: amount,
      currency: currency,
      fallbackLabel: amount != null && currency != null
          ? _formatAmount(amount, currency)
          : youPay,
    );

    return SafariTapPayoutQuote(
      youSend: youSend,
      youPay: youPay,
      artoFees: artoFees,
      paymentMethodFees: paymentMethodFees,
      youWillPay: youWillPay,
      currency: currency,
      amount: amount,
    );
  }

  /// Local fallback when the quote API is unavailable.
  factory SafariTapPayoutQuote.fallback({
    required double amount,
    required String currency,
  }) {
    final label = _formatAmount(amount, currency);
    return SafariTapPayoutQuote(
      youSend: label,
      youPay: label,
      artoFees: 'Free',
      paymentMethodFees: 'Free',
      youWillPay: label,
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
