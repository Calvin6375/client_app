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
    final depositCurrency = _stringOrNull(json['currency'])?.toUpperCase();
    final amount = _asDouble(json['amount'] ?? json['depositAmount']);
    final lines = _indexLines(json['lines']);

    final youDepositLine = _line(lines, const [
      'you_deposit',
      'youDeposit',
      'deposit',
    ]);
    final processingLine = _line(lines, const [
      'processing_fees',
      'processingFees',
      'processing',
    ]);
    final paymentMethodLine = _line(lines, const [
      'payment_method_fees',
      'paymentMethodFees',
      'payment_method',
    ]);
    final youWillPayLine = _line(lines, const [
      'you_will_pay',
      'youWillPay',
      'total',
      'paystack_amount',
    ]);

    final payCurrency = _firstCurrency([
      youWillPayLine?.currency,
      json['paystackCurrency'],
      json['paystack_currency'],
      json['youWillPayCurrency'],
      json['totalToPayCurrency'],
    ]);

    final youDeposit = _display(
      youDepositLine?.display ?? json['youDeposit'] ?? json['you_deposit'],
      fallbackAmount: _asDouble(youDepositLine?.amount) ?? amount,
      currency: youDepositLine?.currency ?? depositCurrency,
      fallbackLabel: amount != null && depositCurrency != null
          ? _formatAmount(amount, depositCurrency)
          : '—',
    );

    final processingFees = _display(
      processingLine?.display ??
          json['processingFees'] ??
          json['processing_fees'],
      fallbackAmount: _asDouble(processingLine?.amount) ??
          _asDouble(json['processingFees'] ?? json['processing_fees']),
      currency: processingLine?.currency ??
          _stringOrNull(json['processingFeesCurrency'])?.toUpperCase(),
      fallbackLabel: 'Free',
    );

    final paymentMethodFees = _display(
      paymentMethodLine?.display ??
          json['paymentMethodFees'] ??
          json['payment_method_fees'],
      fallbackAmount: _asDouble(paymentMethodLine?.amount) ??
          _asDouble(json['paymentMethodFees'] ?? json['payment_method_fees']),
      currency: paymentMethodLine?.currency ??
          _stringOrNull(json['paymentMethodFeesCurrency'])?.toUpperCase(),
      fallbackLabel: 'Free',
    );

    final youWillPay = _display(
      youWillPayLine?.display ??
          json['youWillPay'] ??
          json['you_will_pay'] ??
          json['totalToPay'] ??
          json['paystackAmount'] ??
          json['paystack_amount'],
      fallbackAmount: _asDouble(youWillPayLine?.amount) ??
          _asDouble(
            json['youWillPay'] ??
                json['totalToPay'] ??
                json['paystackAmount'],
          ) ??
          amount,
      currency: payCurrency,
      fallbackLabel: amount != null && (payCurrency ?? depositCurrency) != null
          ? _formatAmount(amount, payCurrency ?? depositCurrency!)
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
      currency: depositCurrency,
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

  static Map<String, _QuoteLine> _indexLines(Object? raw) {
    final indexed = <String, _QuoteLine>{};
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final line = _QuoteLine.fromMap(Map<String, dynamic>.from(item));
        if (line.key.isEmpty) continue;
        indexed[line.key] = line;
      }
      return indexed;
    }
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          final line = _QuoteLine.fromMap(
            Map<String, dynamic>.from(value),
            fallbackKey: key.toString(),
          );
          if (line.key.isNotEmpty) indexed[line.key] = line;
        } else {
          final text = _stringOrNull(value);
          if (text != null) {
            indexed[key.toString()] = _QuoteLine(key: key.toString(), display: text);
          }
        }
      });
    }
    return indexed;
  }

  static _QuoteLine? _line(Map<String, _QuoteLine> lines, List<String> keys) {
    for (final key in keys) {
      final line = lines[key];
      if (line != null) return line;
    }
    return null;
  }

  static String? _firstCurrency(List<Object?> values) {
    for (final value in values) {
      final text = _stringOrNull(value)?.toUpperCase();
      if (text != null && text.isNotEmpty) return text;
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
      if (value == 0 && fallbackLabel.toLowerCase() == 'free') return 'Free';
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
    if (fallbackAmount != null) {
      if (fallbackAmount == 0 && fallbackLabel.toLowerCase() == 'free') {
        return 'Free';
      }
      if (currency != null && currency.isNotEmpty) {
        return _formatAmount(fallbackAmount, currency);
      }
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

class _QuoteLine {
  const _QuoteLine({
    required this.key,
    this.display,
    this.amount,
    this.currency,
  });

  final String key;
  final String? display;
  final double? amount;
  final String? currency;

  factory _QuoteLine.fromMap(
    Map<String, dynamic> json, {
    String? fallbackKey,
  }) {
    return _QuoteLine(
      key: (json['key']?.toString() ?? fallbackKey ?? '').trim(),
      display: TopupQuote._stringOrNull(json['display']),
      amount: TopupQuote._asDouble(json['amount']),
      currency: TopupQuote._stringOrNull(json['currency'])?.toUpperCase(),
    );
  }
}
