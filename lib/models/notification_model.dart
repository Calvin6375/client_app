import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pretium/utils/provider_display_sanitizer.dart';

/// Model representing a notification from Firestore
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String? actionUrl;
  final bool read;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.actionUrl,
    required this.read,
    required this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  /// User-visible title with third-party provider names removed.
  String get displayTitle {
    final sanitized = ProviderDisplaySanitizer.sanitize(title);
    return sanitized.isNotEmpty ? sanitized : title;
  }

  /// User-visible message with third-party provider names removed.
  String get displayMessage {
    final sanitized = ProviderDisplaySanitizer.sanitize(message);
    return sanitized.isNotEmpty ? sanitized : message;
  }

  /// Create NotificationModel from Firestore document
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      actionUrl: data['actionUrl'],
      read: data['read'] ?? false,
      metadata: data['metadata'] ?? {},
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
    );
  }

  /// Convert NotificationModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      if (actionUrl != null) 'actionUrl': actionUrl,
      'read': read,
      'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  /// Create a copy with updated fields
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    String? actionUrl,
    bool? read,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      actionUrl: actionUrl ?? this.actionUrl,
      read: read ?? this.read,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, type: $type, title: $title, read: $read)';
  }

  /// Whether this notification is a promotional/marketing message.
  bool get isPromotion {
    final category = metadata['category']?.toString().toLowerCase();
    if (category == 'promotion' ||
        category == 'promo' ||
        category == 'marketing') {
      return true;
    }

    final normalizedType = type.toLowerCase();
    const promoTypes = {
      'promotion',
      'promo',
      'marketing',
      'offer',
      'campaign',
      'reward',
      'bonus',
      'deal',
    };
    return promoTypes.contains(normalizedType);
  }

  /// Whether this notification relates to a payment, transfer, or wallet activity.
  bool get isTransaction {
    if (isPromotion) return false;
    if (_isExplicitSystem) return false;

    final category = metadata['category']?.toString().toLowerCase();
    if (category == 'transaction' ||
        category == 'payment' ||
        category == 'wallet' ||
        category == 'funding') {
      return true;
    }

    final normalizedType = type.toLowerCase();
    const transactionTypes = {
      'transaction',
      'transaction_completed',
      'transaction_failed',
      'payment',
      'payment_completed',
      'payment_failed',
      'payment_received',
      'transfer',
      'topup',
      'top_up',
      'top-up',
      'deposit',
      'direct_topup',
      'direct_top_up',
      'payout',
      'withdraw',
      'withdrawal',
      'wallet',
      'wallet_credited',
      'wallet_debited',
      'wallet_funded',
      'funding',
      'funding_success',
      'funding_failed',
      'fund',
      'swap',
    };
    if (transactionTypes.contains(normalizedType)) {
      return true;
    }

    if (_hasTransactionMetadata) return true;

    final normalizedTitle = title.toLowerCase();
    const transactionTitleKeywords = [
      'payment received',
      'payment failed',
      'payout',
      'top-up',
      'top up',
      'deposit',
      'withdrawal',
      'transfer',
      'swap',
      'credited',
      'debited',
      'funded',
      'funding',
      'wallet',
    ];
    if (transactionTitleKeywords.any(normalizedTitle.contains)) {
      return true;
    }

    final normalizedMessage = message.toLowerCase();
    const transactionMessageKeywords = [
      'credited with',
      'has been credited',
      'has been debited',
      'debited with',
      'wallet has been',
      'top-up',
      'top up',
      'funding failed',
      'payment received',
      'payment failed',
    ];
    return transactionMessageKeywords.any(normalizedMessage.contains);
  }

  /// System tab: maintenance, outages, and other non-transaction notices.
  bool get isSystem => !isPromotion && !isTransaction;

  bool get _isExplicitSystem {
    final category = metadata['category']?.toString().toLowerCase();
    if (category == 'system' ||
        category == 'maintenance' ||
        category == 'announcement') {
      return true;
    }

    final normalizedType = type.toLowerCase();
    const systemTypes = {
      'system',
      'maintenance',
      'outage',
      'downtime',
      'shutdown',
      'service_update',
      'announcement',
      'app_update',
    };
    if (systemTypes.contains(normalizedType)) {
      return true;
    }

    final normalizedTitle = title.toLowerCase();
    const systemTitleKeywords = [
      'maintenance',
      'scheduled downtime',
      'system update',
      'service interruption',
      'temporarily unavailable',
      'shut down',
      'shutdown',
      'outage',
    ];
    if (systemTitleKeywords.any(normalizedTitle.contains)) {
      return true;
    }

    final normalizedMessage = message.toLowerCase();
    const systemMessageKeywords = [
      'scheduled maintenance',
      'system maintenance',
      'service will be unavailable',
      'temporarily unavailable',
      'planned outage',
    ];
    return systemMessageKeywords.any(normalizedMessage.contains);
  }

  bool get _hasTransactionMetadata {
    const keys = {
      'transactionId',
      'paymentId',
      'fundId',
      'invoiceId',
      'orderId',
      'reference',
      'amount',
      'currency',
    };
    return metadata.keys.any(keys.contains);
  }
}
