import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pretium/models/user_model.dart';
import 'package:pretium/utils/logger.dart';

/// Repository for user profile operations in Firestore
/// All user profile data is stored in Firestore under users/{uid}
class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'users';

  /// Create or update user profile
  Future<void> createUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
  }) async {
    try {
      Logger.info('Creating user profile for: $uid');
      
      final profileData = {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        profileData['phoneNumber'] = phoneNumber;
      }
      
      // Log request body
      final requestBody = {
        'collection': _collection,
        'documentId': uid,
        'data': {
          ...profileData,
          'createdAt': '<FieldValue.serverTimestamp()>',
          'updatedAt': '<FieldValue.serverTimestamp()>',
        },
        'options': {
          'merge': true,
        },
      };
      Logger.info('📤 Firestore - Create User Profile Request:');
      Logger.info('   Request Body: $requestBody');
      
      await _firestore.collection(_collection).doc(uid).set(
        profileData,
        SetOptions(merge: true),
      );
      
      // Fetch the created document to log response
      final doc = await _firestore.collection(_collection).doc(uid).get();
      final responseBody = {
        'success': doc.exists,
        'documentId': doc.id,
        'data': doc.data(),
        'metadata': {
          'hasPendingWrites': doc.metadata.hasPendingWrites,
          'isFromCache': doc.metadata.isFromCache,
        },
      };
      Logger.info('📥 Firestore - Create User Profile Response:');
      Logger.info('   Response Body: $responseBody');
      Logger.success('User profile created successfully: $uid');
    } catch (e) {
      Logger.error('📥 Firestore - Create User Profile Error Response:');
      Logger.error('   Error: $e');
      rethrow;
    }
  }

  /// Get user profile by UID
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      Logger.debug('Fetching user profile: $uid');
      
      final doc = await _firestore.collection(_collection).doc(uid).get();
      
      if (doc.exists) {
        final user = UserModel.fromFirestore(doc);
        Logger.debug('User profile fetched: $uid');
        return user;
      }
      
      Logger.warning('User profile not found: $uid');
      return null;
    } catch (e) {
      Logger.error('Failed to get user profile', e);
      rethrow;
    }
  }

  /// Stream user profile
  Stream<UserModel?> streamUserProfile(String uid) {
    try {
      Logger.debug('Streaming user profile: $uid');
      
      return _firestore
          .collection(_collection)
          .doc(uid)
          .snapshots()
          .map((doc) {
        if (doc.exists) {
          return UserModel.fromFirestore(doc);
        }
        return null;
      });
    } catch (e) {
      Logger.error('Failed to stream user profile', e);
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      Logger.info('Updating user profile: $uid');
      
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (firstName != null) updateData['firstName'] = firstName;
      if (lastName != null) updateData['lastName'] = lastName;
      if (email != null) updateData['email'] = email;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      
      await _firestore.collection(_collection).doc(uid).update(updateData);
      
      Logger.success('User profile updated: $uid');
    } catch (e) {
      Logger.error('Failed to update user profile', e);
      rethrow;
    }
  }
}

