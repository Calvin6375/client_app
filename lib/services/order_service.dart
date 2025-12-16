import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pretium/models/order_model.dart';
import 'package:pretium/utils/logger.dart';

/// Service for creating and managing orders in Firestore
/// Orders are stored in the 'orders' collection
class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'orders';

  /// Create a new order in Firestore
  /// 
  /// Returns the order ID
  /// 
  /// Example:
  /// ```dart
  /// final orderId = await OrderService().createOrder(
  ///   userId: currentUserId,
  ///   amount: 100.0,
  ///   currency: 'USD',
  ///   orderType: 'topup',
  /// );
  /// ```
  Future<String> createOrder({
    required String userId,
    required double amount,
    String? currency,
    String? orderType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      Logger.info('Creating order for user: $userId, amount: $amount');

      // Create order document
      final orderData = {
        'userId': userId,
        'amount': amount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        if (currency != null) 'currency': currency,
        if (orderType != null) 'orderType': orderType,
        if (metadata != null) 'metadata': metadata,
      };

      final docRef = await _firestore.collection(_collection).add(orderData);

      Logger.success('Order created successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      Logger.error('Failed to create order', e);
      rethrow;
    }
  }

  /// Get order by ID
  Future<OrderModel?> getOrder(String orderId) async {
    try {
      Logger.debug('Fetching order: $orderId');

      final doc = await _firestore.collection(_collection).doc(orderId).get();

      if (doc.exists) {
        return OrderModel.fromFirestore(doc);
      }

      Logger.warning('Order not found: $orderId');
      return null;
    } catch (e) {
      Logger.error('Failed to get order', e);
      rethrow;
    }
  }

  /// Stream orders for a specific user
  /// Orders are ordered by createdAt descending
  Stream<List<OrderModel>> streamUserOrders(String userId) {
    try {
      Logger.debug('Streaming orders for user: $userId');

      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      Logger.error('Failed to stream user orders', e);
      rethrow;
    }
  }

  /// Stream all orders (for admin dashboard)
  /// Orders are ordered by createdAt descending
  Stream<List<OrderModel>> streamAllOrders() {
    try {
      Logger.debug('Streaming all orders');

      return _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      Logger.error('Failed to stream all orders', e);
      rethrow;
    }
  }

  /// Update order status
  /// Note: This should typically be called from Cloud Functions for security
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      Logger.info('Updating order status: $orderId -> $status');

      await _firestore.collection(_collection).doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Logger.success('Order status updated: $orderId');
    } catch (e) {
      Logger.error('Failed to update order status', e);
      rethrow;
    }
  }
}

