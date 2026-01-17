import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark 
              ? colors.surface 
              : Colors.white.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: isDark 
              ? null
              : Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  Icon(Icons.flag, color: primary),
                  const SizedBox(width: 8),
                  Text(
                    'Select currency',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: currencies.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
                ),
                itemBuilder: (context, i) {
                  final c = currencies[i];
                  final isSelected = c.code == selectedCode;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDark 
                          ? colors.background 
                          : Colors.white.withOpacity(0.95),
                      child: Text(c.flagEmoji),
                    ),
                    title: Text(
                      c.code,
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    subtitle: Text(
                      c.name,
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
    );
  }
}