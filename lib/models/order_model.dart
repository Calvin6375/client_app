import 'package:cloud_firestore/cloud_firestore.dart';

/// Order model for Firestore
/// Represents an order created by a user
class OrderModel {
  final String id;
  final String userId;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String? currency;
  final String? orderType; // e.g., 'topup', 'swap', 'send_money'
  final Map<String, dynamic>? metadata;

  OrderModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.currency,
    this.orderType,
    this.metadata,
  });

  /// Create OrderModel from Firestore DocumentSnapshot
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return OrderModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      status: data['status'] as String? ?? 'pending',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      currency: data['currency'] as String?,
      orderType: data['orderType'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert OrderModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      if (currency != null) 'currency': currency,
      if (orderType != null) 'orderType': orderType,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Create a copy with updated fields
  OrderModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? status,
    DateTime? createdAt,
    String? currency,
    String? orderType,
    Map<String, dynamic>? metadata,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      currency: currency ?? this.currency,
      orderType: orderType ?? this.orderType,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'OrderModel(id: $id, userId: $userId, amount: $amount, status: $status, createdAt: $createdAt)';
  }
}

