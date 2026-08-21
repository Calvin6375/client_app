import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

/// Shows beneficiary / merchant name after validation, or a placeholder while idle.
class MerchantValidationPanel extends StatelessWidget {
  const MerchantValidationPanel({
    super.key,
    this.beneficiaryName,
    this.loading = false,
    this.error,
    this.idleMessage = 'Recipient name will appear here after validation',
  });

  final String? beneficiaryName;
  final bool loading;
  final String? error;
  final String idleMessage;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = beneficiaryName?.trim();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 128),
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surface.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? colors.surfaceVariant.withValues(alpha: 0.55)
              : const Color(0xFFE5E7EB),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Recipient',
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Validating…', style: TextStyle(color: colors.textSecondary)),
              ],
            )
          else if (error != null && error!.trim().isNotEmpty)
            Text(
              error!,
              style: TextStyle(color: colors.error, fontSize: 14, height: 1.35),
            )
          else if (name != null && name.isNotEmpty)
            Text(
              name,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            )
          else
            Text(
              idleMessage,
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}
