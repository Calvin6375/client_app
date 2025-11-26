import 'package:firebase_database/firebase_database.dart';
import 'package:pretium/models/payment_model.dart';
import 'package:pretium/utils/logger.dart';

/// Repository for payment operations in Realtime Database
/// STRICT RULE: This repository is READ-ONLY
/// Client code MUST NOT create or update payments
/// All payment operations must be done via Cloud Functions
class PaymentRepository {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Stream payments for a user
  /// Path: payments/{uid}
  /// Returns payments ordered by created_at descending
  Stream<List<PaymentModel>> streamUserPayments(String uid, {int? limit}) {
    try {
      Logger.debug('Streaming payments for user: $uid');
      
      Query query = _database.ref('payments').orderByChild('user_id').equalTo(uid);
      
      if (limit != null) {
        query = query.limitToLast(limit);
      }
      
      return query.onValue.map((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final data = event.snapshot.value as Map;
            final payments = <PaymentModel>[];
            
            data.forEach((key, value) {
              try {
                final paymentData = Map<String, dynamic>.from(value as Map);
                paymentData['payment_id'] = key;
                payments.add(PaymentModel.fromJson(paymentData));
              } catch (e) {
                Logger.warning('Failed to parse payment: $key', e);
              }
            });
            
            // Sort by created_at descending (most recent first)
            payments.sort((a, b) {
              final aTime = a.createdAt ?? DateTime(1970);
              final bTime = b.createdAt ?? DateTime(1970);
              return bTime.compareTo(aTime);
            });
            
            Logger.debug('Fetched ${payments.length} payments for user: $uid');
            return payments;
          } catch (e) {
            Logger.error('Failed to parse payments data', e);
            return <PaymentModel>[];
          }
        }
        Logger.debug('No payments found for user: $uid');
        return <PaymentModel>[];
      });
    } catch (e) {
      Logger.error('Failed to stream user payments', e);
      rethrow;
    }
  }

  /// Get a specific payment by ID
  Future<PaymentModel?> getPaymentById(String paymentId) async {
    try {
      Logger.debug('Fetching payment: $paymentId');
      
      final ref = _database.ref('payments/$paymentId');
      final snapshot = await ref.get();
      
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data['payment_id'] = paymentId;
        final payment = PaymentModel.fromJson(data);
        Logger.debug('Payment fetched: $paymentId');
        return payment;
      }
      
      Logger.warning('Payment not found: $paymentId');
      return null;
    } catch (e) {
      Logger.error('Failed to get payment', e);
      rethrow;
    }
  }

  /// Stream a specific payment by ID
  Stream<PaymentModel?> streamPaymentById(String paymentId) {
    try {
      Logger.debug('Streaming payment: $paymentId');
      
      final ref = _database.ref('payments/$paymentId');
      
      return ref.onValue.map((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final data = Map<String, dynamic>.from(
              event.snapshot.value as Map,
            );
            data['payment_id'] = paymentId;
            final payment = PaymentModel.fromJson(data);
            Logger.debug('Payment updated: $paymentId');
            return payment;
          } catch (e) {
            Logger.error('Failed to parse payment data', e);
            return null;
          }
        }
        return null;
      });
    } catch (e) {
      Logger.error('Failed to stream payment', e);
      rethrow;
    }
  }

  /// NOTE: The following methods are intentionally not implemented
  /// Payment creation and updates MUST be done via Cloud Functions only
  ///
  /// To create a payment, call:
  /// PaymentService.createPayment()
  ///
  /// To update payment status, call:
  /// PaymentService.handlePaymentWebhook()
  ///
  /// DO NOT implement createPayment() or updatePayment() here - it's a security risk
}

