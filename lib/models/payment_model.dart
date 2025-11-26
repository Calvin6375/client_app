/// Payment model for Realtime Database
class PaymentModel {
  final String paymentId;
  final String? intasendCheckoutId;
  final String userId;
  final String userEmail;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String? checkoutUrl;
  final CustomerInfo? customerInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? linkOpenedAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final String? transactionId;
  final String? errorReason;
  final Map<String, dynamic>? paymentDetails;
  final String? paymentMethod;
  final String? platform;

  PaymentModel({
    required this.paymentId,
    this.intasendCheckoutId,
    required this.userId,
    required this.userEmail,
    required this.amount,
    required this.currency,
    required this.status,
    this.checkoutUrl,
    this.customerInfo,
    this.createdAt,
    this.updatedAt,
    this.linkOpenedAt,
    this.completedAt,
    this.failedAt,
    this.transactionId,
    this.errorReason,
    this.paymentDetails,
    this.paymentMethod,
    this.platform,
  });

  /// Create from Realtime Database snapshot
  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      paymentId: json['payment_id'] ?? json['paymentId'] ?? '',
      intasendCheckoutId: json['intasend_checkout_id'] ?? json['intasendCheckoutId'],
      userId: json['user_id'] ?? json['userId'] ?? '',
      userEmail: json['user_email'] ?? json['userEmail'] ?? '',
      amount: _parseDouble(json['amount']),
      currency: (json['currency'] ?? 'USD').toString().toUpperCase(),
      status: _parseStatus(json['status']),
      checkoutUrl: json['checkout_url'] ?? json['checkoutUrl'],
      customerInfo: json['customer_info'] != null || json['customerInfo'] != null
          ? CustomerInfo.fromJson(json['customer_info'] ?? json['customerInfo'])
          : null,
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
      linkOpenedAt: _parseDateTime(json['link_opened_at'] ?? json['linkOpenedAt']),
      completedAt: _parseDateTime(json['completed_at'] ?? json['completedAt']),
      failedAt: _parseDateTime(json['failed_at'] ?? json['failedAt']),
      transactionId: json['transaction_id'] ?? json['transactionId'],
      errorReason: json['error_reason'] ?? json['errorReason'],
      paymentDetails: json['payment_details'] ?? json['paymentDetails'],
      paymentMethod: json['payment_method'] ?? json['paymentMethod'],
      platform: json['platform'],
    );
  }

  /// Convert to JSON for Realtime Database
  Map<String, dynamic> toJson() {
    return {
      'payment_id': paymentId,
      if (intasendCheckoutId != null) 'intasend_checkout_id': intasendCheckoutId,
      'user_id': userId,
      'user_email': userEmail,
      'amount': amount,
      'currency': currency,
      'status': status.value,
      if (checkoutUrl != null) 'checkout_url': checkoutUrl,
      if (customerInfo != null) 'customer_info': customerInfo!.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (linkOpenedAt != null) 'link_opened_at': linkOpenedAt!.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (failedAt != null) 'failed_at': failedAt!.toIso8601String(),
      if (transactionId != null) 'transaction_id': transactionId,
      if (errorReason != null) 'error_reason': errorReason,
      if (paymentDetails != null) 'payment_details': paymentDetails,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (platform != null) 'platform': platform,
    };
  }

  /// Create a copy with updated fields
  PaymentModel copyWith({
    String? paymentId,
    String? intasendCheckoutId,
    String? userId,
    String? userEmail,
    double? amount,
    String? currency,
    PaymentStatus? status,
    String? checkoutUrl,
    CustomerInfo? customerInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? linkOpenedAt,
    DateTime? completedAt,
    DateTime? failedAt,
    String? transactionId,
    String? errorReason,
    Map<String, dynamic>? paymentDetails,
    String? paymentMethod,
    String? platform,
  }) {
    return PaymentModel(
      paymentId: paymentId ?? this.paymentId,
      intasendCheckoutId: intasendCheckoutId ?? this.intasendCheckoutId,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      checkoutUrl: checkoutUrl ?? this.checkoutUrl,
      customerInfo: customerInfo ?? this.customerInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      linkOpenedAt: linkOpenedAt ?? this.linkOpenedAt,
      completedAt: completedAt ?? this.completedAt,
      failedAt: failedAt ?? this.failedAt,
      transactionId: transactionId ?? this.transactionId,
      errorReason: errorReason ?? this.errorReason,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      platform: platform ?? this.platform,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static PaymentStatus _parseStatus(dynamic value) {
    if (value == null) return PaymentStatus.initiated;
    final statusStr = value.toString().toLowerCase();
    return PaymentStatus.values.firstWhere(
      (status) => status.value == statusStr,
      orElse: () => PaymentStatus.initiated,
    );
  }

  @override
  String toString() {
    return 'PaymentModel(paymentId: $paymentId, status: ${status.value}, amount: $amount $currency)';
  }
}

/// Payment status enum
enum PaymentStatus {
  initiated('initiated'),
  linkOpened('link_opened'),
  completed('completed'),
  failed('failed');

  final String value;
  const PaymentStatus(this.value);
}

/// Customer information
class CustomerInfo {
  final String email;
  final String firstName;
  final String lastName;

  CustomerInfo({
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? json['firstName'] ?? '',
      lastName: json['last_name'] ?? json['lastName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
    };
  }

  String get fullName => '$firstName $lastName'.trim();
}

