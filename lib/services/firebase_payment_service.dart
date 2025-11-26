import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Service for managing payment data in Firebase Realtime Database
class FirebasePaymentService {
  static const String _databaseUrl = 'https://truepay-72060-default-rtdb.firebaseio.com/';
  
  static FirebaseDatabase? _database;
  
  /// Initialize Firebase Realtime Database with custom URL
  static FirebaseDatabase get database {
    _database ??= FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _databaseUrl,
    );
    return _database!;
  }
  
  /// Generate unique payment ID
  static String generatePaymentId() {
    return 'payment_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';
  }
  
  /// Store payment initiation data when checkout link is created
  static Future<Map<String, dynamic>> storePaymentInitiation({
    required String paymentId,
    required double amount,
    required String currency,
    required String email,
    required String firstName,
    required String lastName,
    required String checkoutUrl,
    required String intaSendCheckoutId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final timestamp = DateTime.now().toIso8601String();
      
      final paymentData = {
        'payment_id': paymentId,
        'intasend_checkout_id': intaSendCheckoutId,
        'user_id': user?.uid ?? 'anonymous',
        'user_email': user?.email ?? email,
        'amount': amount,
        'currency': currency.toUpperCase(),
        'customer_info': {
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
        },
        'checkout_url': checkoutUrl,
        'status': 'initiated', // initiated -> link_opened -> completed/failed
        'created_at': timestamp,
        'updated_at': timestamp,
        'payment_method': 'intasend',
        'platform': 'mobile_app',
        if (additionalData != null) ...additionalData,
      };
      
      // Store in payments collection
      final DatabaseReference paymentsRef = database.ref('payments/$paymentId');
      await paymentsRef.set(paymentData);
      
      // Also store in user's payment history if user is authenticated
      if (user != null) {
        final DatabaseReference userPaymentRef = database.ref('users/${user.uid}/payments/$paymentId');
        await userPaymentRef.set({
          'payment_id': paymentId,
          'amount': amount,
          'currency': currency,
          'status': 'initiated',
          'created_at': timestamp,
        });
      }
      
      print('💾 Payment initiation stored successfully:');
      print('  Payment ID: $paymentId');
      print('  Database URL: $_databaseUrl');
      print('  Amount: $amount $currency');
      print('  Customer: $firstName $lastName ($email)');
      
      return {
        'success': true,
        'payment_id': paymentId,
        'database_path': 'payments/$paymentId',
      };
      
    } catch (e) {
      print('🚨 Error storing payment initiation: $e');
      return {
        'success': false,
        'error': 'Failed to store payment data: $e',
      };
    }
  }
  
  /// Update payment status when checkout link is opened
  static Future<Map<String, dynamic>> markPaymentLinkOpened({
    required String paymentId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      
      final updateData = {
        'status': 'link_opened',
        'link_opened_at': timestamp,
        'updated_at': timestamp,
        if (additionalData != null) ...additionalData,
      };
      
      final DatabaseReference paymentRef = database.ref('payments/$paymentId');
      await paymentRef.update(updateData);
      
      // Also update user's payment history if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final DatabaseReference userPaymentRef = database.ref('users/${user.uid}/payments/$paymentId');
        await userPaymentRef.update({
          'status': 'link_opened',
          'link_opened_at': timestamp,
        });
      }
      
      print('🔗 Payment link opened status updated:');
      print('  Payment ID: $paymentId');
      print('  Status: link_opened');
      print('  Timestamp: $timestamp');
      
      return {
        'success': true,
        'payment_id': paymentId,
        'status': 'link_opened',
      };
      
    } catch (e) {
      print('🚨 Error updating payment status: $e');
      return {
        'success': false,
        'error': 'Failed to update payment status: $e',
      };
    }
  }
  
  /// Mark payment as completed (call this when payment is verified via webhook)
  static Future<Map<String, dynamic>> markPaymentCompleted({
    required String paymentId,
    String? transactionId,
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      
      final updateData = {
        'status': 'completed',
        'completed_at': timestamp,
        'updated_at': timestamp,
        if (transactionId != null) 'transaction_id': transactionId,
        if (paymentDetails != null) 'payment_details': paymentDetails,
      };
      
      final DatabaseReference paymentRef = database.ref('payments/$paymentId');
      await paymentRef.update(updateData);
      
      // Also update user's payment history
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final DatabaseReference userPaymentRef = database.ref('users/${user.uid}/payments/$paymentId');
        await userPaymentRef.update({
          'status': 'completed',
          'completed_at': timestamp,
          if (transactionId != null) 'transaction_id': transactionId,
        });
      }
      
      print('✅ Payment marked as completed:');
      print('  Payment ID: $paymentId');
      print('  Transaction ID: $transactionId');
      
      return {
        'success': true,
        'payment_id': paymentId,
        'status': 'completed',
      };
      
    } catch (e) {
      print('🚨 Error marking payment completed: $e');
      return {
        'success': false,
        'error': 'Failed to mark payment completed: $e',
      };
    }
  }
  
  /// Mark payment as failed
  static Future<Map<String, dynamic>> markPaymentFailed({
    required String paymentId,
    String? errorReason,
    Map<String, dynamic>? errorDetails,
  }) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      
      final updateData = {
        'status': 'failed',
        'failed_at': timestamp,
        'updated_at': timestamp,
        if (errorReason != null) 'error_reason': errorReason,
        if (errorDetails != null) 'error_details': errorDetails,
      };
      
      final DatabaseReference paymentRef = database.ref('payments/$paymentId');
      await paymentRef.update(updateData);
      
      // Also update user's payment history
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final DatabaseReference userPaymentRef = database.ref('users/${user.uid}/payments/$paymentId');
        await userPaymentRef.update({
          'status': 'failed',
          'failed_at': timestamp,
          if (errorReason != null) 'error_reason': errorReason,
        });
      }
      
      print('❌ Payment marked as failed:');
      print('  Payment ID: $paymentId');
      print('  Reason: $errorReason');
      
      return {
        'success': true,
        'payment_id': paymentId,
        'status': 'failed',
      };
      
    } catch (e) {
      print('🚨 Error marking payment failed: $e');
      return {
        'success': false,
        'error': 'Failed to mark payment failed: $e',
      };
    }
  }
  
  /// Get payment details by ID
  static Future<Map<String, dynamic>?> getPaymentById(String paymentId) async {
    try {
      final DatabaseReference paymentRef = database.ref('payments/$paymentId');
      final DataSnapshot snapshot = await paymentRef.get();
      
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
      
    } catch (e) {
      print('🚨 Error getting payment: $e');
      return null;
    }
  }
  
  /// Get user's payment history
  static Future<List<Map<String, dynamic>>> getUserPayments({int? limit}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      Query query = database.ref('users/${user.uid}/payments')
          .orderByChild('created_at');
      
      if (limit != null) {
        query = query.limitToLast(limit);
      }
      
      final DataSnapshot snapshot = await query.get();
      
      if (snapshot.exists) {
        final Map paymentsMap = snapshot.value as Map;
        return paymentsMap.values
            .map((payment) => Map<String, dynamic>.from(payment as Map))
            .toList()
            .reversed
            .toList(); // Most recent first
      }
      
      return [];
      
    } catch (e) {
      print('🚨 Error getting user payments: $e');
      return [];
    }
  }
}