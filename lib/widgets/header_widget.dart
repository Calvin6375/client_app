import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  bool _isFirebaseInitialized() {
    return Firebase.apps.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    // Check if Firebase is initialized before accessing FirebaseAuth
    if (!_isFirebaseInitialized()) {
      final primary = Theme.of(context).colorScheme.primary;
      return Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              'U',
              style: TextStyle(
                color: primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Hello 👋',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final user = FirebaseAuth.instance.currentUser;

    // If no user is logged in, show a simple placeholder header
    if (user == null) {
      final primary = Theme.of(context).colorScheme.primary;
      return Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              'U',
              style: TextStyle(
                color: primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Hello 👋',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final uid = user.uid;
    
    // Wrap Firestore access in try-catch to handle errors gracefully
    Stream<DocumentSnapshot<Map<String, dynamic>>>? userDocStream;
    try {
      userDocStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    } catch (e) {
      // If Firestore fails, show default UI
      final primary = Theme.of(context).colorScheme.primary;
      return Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              (user.email?.isNotEmpty ?? false) ? user.email![0].toUpperCase() : 'U',
              style: TextStyle(
                color: primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.email?.isNotEmpty ?? false 
                  ? 'Hello, ${user.email!.split('@').first} 👋'
                  : 'Hello 👋',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDocStream,
      builder: (context, snapshot) {
        // Handle errors in the stream
        if (snapshot.hasError) {
          final primary = Theme.of(context).colorScheme.primary;
          return Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (user.email?.isNotEmpty ?? false) ? user.email![0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user.email?.isNotEmpty ?? false 
                      ? 'Hello, ${user.email!.split('@').first} 👋'
                      : 'Hello 👋',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }
        String firstName = '';
        String lastName = '';
        String email = user.email ?? '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          if (data != null) {
            firstName = (data['firstName'] ?? '').toString();
            lastName = (data['lastName'] ?? '').toString();
          }
        }

        final displayName =
            (firstName.isNotEmpty
                    ? lastName.isNotEmpty ? '$firstName $lastName' : firstName
                    : (email.isNotEmpty ? email.split('@').first : ''))
                .trim();
        final avatarInitial =
            (firstName.isNotEmpty
                    ? firstName[0]
                    : (email.isNotEmpty ? email[0] : 'U'))
                .toUpperCase();

        return Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                avatarInitial,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName.isNotEmpty ? 'Hello, $displayName 👋' : 'Hello 👋',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {},
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
