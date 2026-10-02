import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/core/providers/auth_providers.dart';
import 'package:pretium/core/providers/user_profile_provider.dart';
import 'package:pretium/features/notifications/providers/notifications_provider.dart';
import 'package:pretium/utils/firebase_utils.dart';
import 'package:pretium/widgets/tappable_user_avatar.dart';

class HeaderWidget extends ConsumerWidget {
  const HeaderWidget({super.key});

  Widget _buildClickableAvatar(BuildContext context, String initial) {
    return TappableUserAvatar(
      initial: initial,
      tooltip: 'Wallet settings',
      badgeIcon: Icons.arrow_forward_ios_rounded,
      onTap: () => Navigator.of(context).pushNamed(RouteNames.walletSettings),
    );
  }

  Widget _buildHeaderLayout({
    required BuildContext context,
    required String avatarInitial,
    required String displayName,
    String? userId,
  }) {
    final colors = AppColors.getThemeColors(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildClickableAvatar(context, avatarInitial),
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
        IconButton(
          tooltip: 'Help',
          icon: Icon(
            Icons.help_outline,
            color: colors.textPrimary,
            size: 26,
          ),
          onPressed: () =>
              Navigator.of(context).pushNamed(RouteNames.contactSupport),
        ),
        if (userId != null) _NotificationBellButton(userId: userId),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isFirebaseInitialized()) {
      return _buildHeaderLayout(
        context: context,
        avatarInitial: 'U',
        displayName: 'Guest',
      );
    }

    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return _buildHeaderLayout(
        context: context,
        avatarInitial: 'U',
        displayName: 'Guest',
      );
    }

    final profile = ref.watch(userProfileProvider).valueOrNull;
    final email = user.email ?? '';
    final firstName = profile?.firstName.trim() ?? '';
    final displayName = firstName.isNotEmpty
        ? firstName
        : (email.isNotEmpty ? email.split('@').first : '');
    final avatarInitial = (firstName.isNotEmpty
            ? firstName[0]
            : (email.isNotEmpty ? email[0] : 'U'))
        .toUpperCase();

    return _buildHeaderLayout(
      context: context,
      avatarInitial: avatarInitial,
      displayName: displayName.isNotEmpty ? displayName : 'Guest',
      userId: user.uid,
    );
  }
}

class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.getThemeColors(context);
    final hasUnread =
        ref.watch(notificationsProvider).valueOrNull?.any((n) => !n.read) ??
            false;

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
  }
}
