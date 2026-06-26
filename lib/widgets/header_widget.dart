import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/models/notification_model.dart';
import 'package:pretium/services/notification_service.dart';
import 'package:pretium/utils/firebase_utils.dart';

class HeaderWidget extends StatelessWidget {
  HeaderWidget({super.key});

  Widget _buildClickableAvatar(
    BuildContext context,
    String initial,
    Color primary,
  ) {
    final colors = AppColors.getThemeColors(context);
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(RouteNames.walletSettings),
      borderRadius: BorderRadius.circular(20),
      child: CircleAvatar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? colors.onPrimary // White for dark mode
            : primary.withOpacity(0.1), // Light teal background for light mode
        child: Text(
          initial,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? primary // Teal text on white for dark mode
                : primary, // Teal text on light background for light mode
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
    if (!isFirebaseInitialized()) {
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
                fontWeight: FontWeight.w600, // Medium weight - professional
                color: AppColors.getThemeColors(context).textPrimary, // Theme-aware text color
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
                fontWeight: FontWeight.w600, // Medium weight - professional
                color: AppColors.getThemeColors(context).textPrimary, // Theme-aware text color
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
                color: colors.textPrimary, // Black text for visibility in light mode
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
                    color: colors.textPrimary, // Theme-aware primary text
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
                  color: colors.textPrimary, // Black text for visibility in light mode
                ),
                textAlign: TextAlign.left,
              ),
            ),
            _NotificationBellButton(userId: uid),
          ],
        );
      },
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return StreamBuilder<List<NotificationModel>>(
      stream: NotificationService().getNotificationsStream(userId),
      builder: (context, snapshot) {
        final hasUnread = snapshot.data?.any((n) => !n.read) ?? false;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                color: colors.textPrimary,
                size: 28,
              ),
              onPressed: () {
                Navigator.of(context).pushNamed(RouteNames.notifications);
              },
            ),
            if (hasUnread)
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
        );
      },
    );
  }
}
