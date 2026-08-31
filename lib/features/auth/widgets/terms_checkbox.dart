import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

class TermsCheckbox extends StatelessWidget {
  final bool termsAccepted;
  final bool privacyAccepted;
  final ValueChanged<bool?> onTermsChanged;
  final ValueChanged<bool?> onPrivacyChanged;
  final VoidCallback? onTermsTap;
  final VoidCallback? onPrivacyTap;
  /// When false, the Terms checkbox cannot be ticked yet.
  final bool canAcceptTerms;
  /// When false, the Privacy checkbox cannot be ticked yet.
  final bool canAcceptPrivacy;
  final Color? color;

  const TermsCheckbox({
    super.key,
    required this.termsAccepted,
    required this.privacyAccepted,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    this.onTermsTap,
    this.onPrivacyTap,
    this.canAcceptTerms = true,
    this.canAcceptPrivacy = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final checkboxColor = color ?? colors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalAcceptRow(
          accepted: termsAccepted,
          canAccept: canAcceptTerms,
          checkboxColor: checkboxColor,
          onPrimary: colors.onPrimary,
          borderColor: colors.border,
          textSecondary: colors.textSecondary,
          linkLabel: 'Terms and Conditions',
          onLinkTap: onTermsTap,
          onChanged: onTermsChanged,
          blockedMessage:
              'Open and scroll to the bottom of the Terms and Conditions first.',
        ),
        _LegalAcceptRow(
          accepted: privacyAccepted,
          canAccept: canAcceptPrivacy,
          checkboxColor: checkboxColor,
          onPrimary: colors.onPrimary,
          borderColor: colors.border,
          textSecondary: colors.textSecondary,
          linkLabel: 'Privacy Policy',
          onLinkTap: onPrivacyTap,
          onChanged: onPrivacyChanged,
          blockedMessage:
              'Open and scroll to the bottom of the Privacy Policy first.',
        ),
      ],
    );
  }
}

class _LegalAcceptRow extends StatelessWidget {
  const _LegalAcceptRow({
    required this.accepted,
    required this.canAccept,
    required this.checkboxColor,
    required this.onPrimary,
    required this.borderColor,
    required this.textSecondary,
    required this.linkLabel,
    required this.onLinkTap,
    required this.onChanged,
    required this.blockedMessage,
  });

  final bool accepted;
  final bool canAccept;
  final Color checkboxColor;
  final Color onPrimary;
  final Color borderColor;
  final Color textSecondary;
  final String linkLabel;
  final VoidCallback? onLinkTap;
  final ValueChanged<bool?> onChanged;
  final String blockedMessage;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      decoration: TextDecoration.underline,
      color: checkboxColor,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );
    final plainStyle = TextStyle(
      color: textSecondary,
      fontSize: 14,
      height: 1.35,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: accepted,
          activeColor: checkboxColor,
          checkColor: onPrimary,
          side: BorderSide(color: borderColor, width: 3.0),
          onChanged: canAccept
              ? onChanged
              : (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(blockedMessage)),
                  );
                },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('I accept the ', style: plainStyle),
                GestureDetector(
                  onTap: onLinkTap,
                  child: Text(linkLabel, style: linkStyle),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
