import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactSupportPage extends StatelessWidget {
  const ContactSupportPage({super.key});

  static const supportEmail = 'support@truepay.live';
  static const supportPhone = '+254739614369';
  static const supportPhoneDigits = '254739614369';
  static const supportPhoneDisplay = '+254 739614369';

  static final _launchGuard = AsyncActionGuard();

  Future<void> _launch(BuildContext context, Uri uri) async {
    await _launchGuard.run(() async {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open. Please try again.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: colors.textPrimary,
        ),
        title: Text(
          'Contact Support',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'We\'re here to help',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reach our support team by email, WhatsApp, or phone.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            _SupportOptionTile(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: supportEmail,
              primary: primary,
              onTap: () => _launch(
                context,
                Uri(
                  scheme: 'mailto',
                  path: supportEmail,
                  queryParameters: const {'subject': 'TruePay Support Request'},
                ),
              ),
            ),
            _SupportOptionTile(
              faIcon: FontAwesomeIcons.whatsapp,
              title: 'WhatsApp',
              subtitle: supportPhoneDisplay,
              primary: primary,
              onTap: () => _launch(
                context,
                Uri.parse('https://wa.me/$supportPhoneDigits'),
              ),
            ),
            _SupportOptionTile(
              icon: Icons.phone_outlined,
              title: 'Call',
              subtitle: supportPhoneDisplay,
              primary: primary,
              onTap: () => _launch(
                context,
                Uri(scheme: 'tel', path: supportPhone),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Support is instant and 24/7.',
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SupportOptionTile extends StatelessWidget {
  const _SupportOptionTile({
    this.icon,
    this.faIcon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  }) : assert(icon != null || faIcon != null);

  final IconData? icon;
  final IconData? faIcon;
  final String title;
  final String subtitle;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withOpacity(0.5)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: primary.withOpacity(0.12),
          child: faIcon != null
              ? FaIcon(faIcon, color: primary, size: 22)
              : Icon(icon, color: primary, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: colors.textTertiary,
        ),
      ),
    );
  }
}
