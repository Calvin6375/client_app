import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pretium/services/auth_service.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/core/constants/app_colors.dart';

class HeaderWidget extends StatelessWidget {
  HeaderWidget({super.key});

  final AuthService _authService = AuthService();

  bool _isFirebaseInitialized() {
    return Firebase.apps.isNotEmpty;
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await _authService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      RouteNames.login,
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logout failed: ${e.toString()}'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildClickableAvatar(
    BuildContext context,
    String initial,
    Color primary,
  ) {
    final colors = AppColors.getThemeColors(context);
    return InkWell(
      onTap: () => _showLogoutDialog(context),
      borderRadius: BorderRadius.circular(20),
      child: CircleAvatar(
        backgroundColor: colors.onPrimary,
        child: Text(
          initial,
          style: TextStyle(
            color: primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if Firebase is initialized before accessing FirebaseAuth
    if (!_isFirebaseInitialized()) {
      final primary = Theme.of(context).colorScheme.primary;
      return Row(
        children: [
          _buildClickableAvatar(context, 'U', primary),
          const SizedBox(width: 12),
              Expanded(
            child: Text(
              'Hello 👋',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getThemeColors(context).onPrimary,
              ),
              textAlign: TextAlign.left,
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
          _buildClickableAvatar(context, 'U', primary),
          const SizedBox(width: 12),
              Expanded(
            child: Text(
              'Hello 👋',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getThemeColors(context).onPrimary,
              ),
              textAlign: TextAlign.left,
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
      final colors = AppColors.getThemeColors(context);
      final primary = Theme.of(context).colorScheme.primary;
      return Row(
        children: [
          _buildClickableAvatar(
            context,
            (user.email?.isNotEmpty ?? false) ? user.email![0].toUpperCase() : 'U',
            primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.email?.isNotEmpty ?? false 
                  ? 'Hello, ${user.email!.split('@').first} 👋'
                  : 'Hello 👋',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.onPrimary,
              ),
              textAlign: TextAlign.left,
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
          final colors = AppColors.getThemeColors(context);
          final primary = Theme.of(context).colorScheme.primary;
          return Row(
            children: [
              _buildClickableAvatar(
                context,
                (user.email?.isNotEmpty ?? false) ? user.email![0].toUpperCase() : 'U',
                primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user.email?.isNotEmpty ?? false 
                      ? 'Hello, ${user.email!.split('@').first} 👋'
                      : 'Hello 👋',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                  ),
                  textAlign: TextAlign.left,
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

        final colors = AppColors.getThemeColors(context);
        return Row(
          children: [
            _buildClickableAvatar(
              context,
              avatarInitial,
              Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName.isNotEmpty ? 'Hello, $displayName 👋' : 'Hello 👋',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimary,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: colors.onPrimary,
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
                    decoration: BoxDecoration(
                      color: colors.error,
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
