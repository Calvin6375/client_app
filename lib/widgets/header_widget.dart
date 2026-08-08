import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/models/notification_model.dart';
import 'package:pretium/services/notification_service.dart';
import 'package:pretium/utils/firebase_utils.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

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
        radius: 22,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? colors.onPrimary // White for dark mode
            : primary.withValues(alpha: 0.1), // Light teal background for light mode
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

  Widget _buildHeaderLayout({
    required BuildContext context,
    required String avatarInitial,
    required String displayName,
    String? userId,
  }) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildClickableAvatar(context, avatarInitial, primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (userId != null) _NotificationBellButton(userId: userId),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if Firebase is initialized before accessing FirebaseAuth
    if (!isFirebaseInitialized()) {
      return _buildHeaderLayout(
        context: context,
        avatarInitial: 'U',
        displayName: 'Guest',
      );
    }

    final user = FirebaseAuth.instance.currentUser;

    // If no user is logged in, show a simple placeholder header
    if (user == null) {
      return _buildHeaderLayout(
        context: context,
        avatarInitial: 'U',
        displayName: 'Guest',
      );
    }

    final uid = user.uid;
    
    // Wrap Firestore access in try-catch to handle errors gracefully
    Stream<DocumentSnapshot<Map<String, dynamic>>>? userDocStream;
    try {
      userDocStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    } catch (e) {
      // If Firestore fails, show default UI
      return _buildHeaderLayout(
        context: context,
        avatarInitial: (user.email?.isNotEmpty ?? false)
            ? user.email![0].toUpperCase()
            : 'U',
        displayName: user.email?.isNotEmpty ?? false
            ? user.email!.split('@').first
            : 'Guest',
        userId: uid,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDocStream,
      builder: (context, snapshot) {
        // Handle errors in the stream
        if (snapshot.hasError) {
          return _buildHeaderLayout(
            context: context,
            avatarInitial: (user.email?.isNotEmpty ?? false)
                ? user.email![0].toUpperCase()
                : 'U',
            displayName: user.email?.isNotEmpty ?? false
                ? user.email!.split('@').first
                : 'Guest',
            userId: uid,
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

        return _buildHeaderLayout(
          context: context,
          avatarInitial: avatarInitial,
          displayName: displayName.isNotEmpty ? displayName : 'Guest',
          userId: uid,
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
