import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/widgets/currency_logo.dart';

class Currency {
  final String code; // e.g., NGN, USD
  final String name; // e.g., Nigerian Naira
  final String flagEmoji; // simple flag representation for demo
  const Currency({required this.code, required this.name, required this.flagEmoji});
}

class CurrencyPickerBottomSheet extends StatelessWidget {
  final List<Currency> currencies;
  final String selectedCode;
  final ValueChanged<Currency> onSelected;
  const CurrencyPickerBottomSheet({super.key, required this.currencies, required this.selectedCode, required this.onSelected});

  /// Shared with the bank picker so both sheets match visually.
  static double sheetHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height * 0.55;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final sheetColor =
        isDark ? colors.surface : Colors.white.withValues(alpha: 0.9);

    return SafeArea(
      child: Material(
        color: sheetColor,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          side: isDark
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: sheetHeight(context),
          child: Column(
            children: [
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: colors.textTertiary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: primary),
                  const SizedBox(width: 8),
                  Text(
                    'Select wallet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: currencies.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
                ),
                itemBuilder: (context, i) {
                  final c = currencies[i];
                  final isSelected = c.code == selectedCode;
                  final logoSize = CurrencyLogo.hasAssetLogo(c.code) ? 26.0 : 24.0;
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.background
                            : Colors.white.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? colors.border.withValues(alpha: 0.45)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: CurrencyLogo(
                        code: c.code,
                        size: logoSize,
                        // Prefer catalog flags/logos; only use model emoji if real.
                        fallbackEmoji: c.flagEmoji,
                      ),
                    ),
                    title: Text(
                      c.code,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      c.name.isNotEmpty ? c.name : CurrencyLogo.displayNameFor(c.code),
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: primary)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(c);
                    },
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
