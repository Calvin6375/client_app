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
  }) async {
    try {
      Logger.info('Creating user profile for: $uid');
      
      await _firestore.collection(_collection).doc(uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      Logger.success('User profile created successfully: $uid');
    } catch (e) {
      Logger.error('Failed to create user profile', e);
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
  }) async {
    try {
      Logger.info('Updating user profile: $uid');
      
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (firstName != null) updateData['firstName'] = firstName;
      if (lastName != null) updateData['lastName'] = lastName;
      if (email != null) updateData['email'] = email;
      
      await _firestore.collection(_collection).doc(uid).update(updateData);
      
      Logger.success('User profile updated: $uid');
    } catch (e) {
      Logger.error('Failed to update user profile', e);
      rethrow;
    }
  }
}

