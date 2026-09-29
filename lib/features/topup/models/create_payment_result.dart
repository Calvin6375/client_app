/// Outcome of `createPayment`. Creating a Grid order is not a completed payment.
enum CreatePaymentFlow {
  hostedCheckout,
  gridUsdInstructions,
  error,
}

class FundingAccountInfo {
  const FundingAccountInfo({
    this.reference,
    this.bankName,
    this.accountHolderName,
    this.accountNumber,
    this.accountType,
    this.routingNumber,
    this.swiftCode,
    this.bankAddress,
    this.country,
    this.paymentRails = const [],
  });

  final String? reference;
  final String? bankName;
  final String? accountHolderName;
  final String? accountNumber;
  final String? accountType;
  final String? routingNumber;
  final String? swiftCode;
  final String? bankAddress;
  final String? country;
  final List<String> paymentRails;

  factory FundingAccountInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FundingAccountInfo();
    return FundingAccountInfo(
      reference: _nonEmpty(json['reference']),
      bankName: _nonEmpty(json['bankName']),
      accountHolderName: _nonEmpty(json['accountHolderName']),
      accountNumber: _nonEmpty(json['accountNumber']),
      accountType: _nonEmpty(json['accountType']),
      routingNumber: _nonEmpty(json['routingNumber']),
      swiftCode: _nonEmpty(json['swiftCode']),
      bankAddress: _nonEmpty(json['bankAddress']),
      country: _nonEmpty(json['country']),
      paymentRails: _stringList(json['paymentRails']),
    );
  }

  bool get isEmpty =>
      reference == null &&
      bankName == null &&
      accountHolderName == null &&
      accountNumber == null &&
      accountType == null &&
      routingNumber == null &&
      swiftCode == null &&
      bankAddress == null &&
      country == null &&
      paymentRails.isEmpty;
}

class FundingPaymentInstruction {
  const FundingPaymentInstruction({
    this.account = const FundingAccountInfo(),
    this.instructionsNotes,
  });

  final FundingAccountInfo account;
  final String? instructionsNotes;

  factory FundingPaymentInstruction.fromJson(Map<String, dynamic> json) {
    final infoRaw = json['accountOrWalletInfo'];
    return FundingPaymentInstruction(
      account: FundingAccountInfo.fromJson(_asStringKeyMap(infoRaw)),
      instructionsNotes: _nonEmpty(json['instructionsNotes']),
    );
  }

  bool get hasContent =>
      !account.isEmpty || (instructionsNotes != null && instructionsNotes!.isNotEmpty);

  static List<FundingPaymentInstruction> listFrom(Object? raw) {
    return _parseInstructions(raw);
  }
}

class CreatePaymentResult {
  const CreatePaymentResult({
    required this.flow,
    this.error,
    this.checkoutUrl,
    this.invoiceId,
    this.fundingOrderId,
    this.amount,
    this.currency,
    this.status,
    this.provider,
    this.instructions = const [],
  });

  final CreatePaymentFlow flow;
  final String? error;
  final String? checkoutUrl;
  final String? invoiceId;
  final String? fundingOrderId;
  final double? amount;
  final String? currency;
  final String? status;
  final String? provider;
  final List<FundingPaymentInstruction> instructions;

  bool get isError => flow == CreatePaymentFlow.error;
  bool get opensHostedCheckout => flow == CreatePaymentFlow.hostedCheckout;
  bool get showsGridUsdInstructions =>
      flow == CreatePaymentFlow.gridUsdInstructions;

  /// createPayment never means the wallet was credited.
  bool get isPaymentSettled => false;

  factory CreatePaymentResult.error(String message) {
    return CreatePaymentResult(
      flow: CreatePaymentFlow.error,
      error: message,
    );
  }

  factory CreatePaymentResult.fromResponse(
    Object? raw, {
    String? requestedProvider,
  }) {
    final data = _asStringKeyMap(raw);
    if (data == null) {
      return CreatePaymentResult.error('Invalid payment response');
    }

    if (data['success'] != true) {
      return CreatePaymentResult.error(
        _nonEmpty(data['error']) ?? 'Payment failed',
      );
    }

    final provider = (_nonEmpty(data['provider']) ?? requestedProvider)
        ?.trim()
        .toLowerCase();
    final currency = _nonEmpty(data['currency'])?.toUpperCase();
    final status = _nonEmpty(data['status'])?.toLowerCase();
    final checkoutUrl = _firstNonEmpty([
      data['checkoutUrl'],
      data['checkout_url'],
      data['url'],
      data['authorization_url'],
    ]);
    final invoiceId = _firstNonEmpty([
      data['invoiceId'],
      data['paymentId'],
      data['orderId'],
      data['fundingOrderId'],
    ]);
    final fundingOrderId = _firstNonEmpty([
      data['fundingOrderId'],
      data['orderId'],
      data['invoiceId'],
      data['paymentId'],
    ]);
    final amount = _asDouble(data['amount'] ?? data['totalToPay']);
    final instructions = _parseInstructions(data['fundingPaymentInstructions']);

    final isGridUsd = provider == 'grid' && currency == 'USD';
    if (isGridUsd) {
      if (instructions.isEmpty) {
        return CreatePaymentResult.error(
          'Funding instructions were not returned. Please try again.',
        );
      }
      return CreatePaymentResult(
        flow: CreatePaymentFlow.gridUsdInstructions,
        invoiceId: invoiceId,
        fundingOrderId: fundingOrderId,
        amount: amount,
        currency: currency,
        status: status ?? 'pending',
        provider: provider,
        instructions: instructions,
      );
    }

    if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
      if (invoiceId == null || invoiceId.isEmpty) {
        return CreatePaymentResult.error(
          'Payment reference is missing from server response',
        );
      }
      return CreatePaymentResult(
        flow: CreatePaymentFlow.hostedCheckout,
        checkoutUrl: checkoutUrl,
        invoiceId: invoiceId,
        fundingOrderId: fundingOrderId,
        amount: amount,
        currency: currency,
        status: status,
        provider: provider,
      );
    }

    return CreatePaymentResult.error('No checkout URL returned from server');
  }
}

Map<String, dynamic>? _asStringKeyMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

List<FundingPaymentInstruction> _parseInstructions(Object? raw) {
  if (raw is! List) return const [];
  final items = <FundingPaymentInstruction>[];
  for (final item in raw) {
    final map = _asStringKeyMap(item);
    if (map == null) continue;
    final instruction = FundingPaymentInstruction.fromJson(map);
    if (instruction.hasContent) items.add(instruction);
  }
  return items;
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String? _nonEmpty(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}

String? _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = _nonEmpty(value);
    if (text != null) return text;
  }
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', ''));
  return null;
}
