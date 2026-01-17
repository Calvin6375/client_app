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
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark, // Dark slate card
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.flag, color: AppColors.brandPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'Select currency',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: currencies.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.surfaceVariantDark),
                itemBuilder: (context, i) {
                  final c = currencies[i];
                  final isSelected = c.code == selectedCode;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.backgroundDeepNavy,
                      child: Text(c.flagEmoji),
                    ),
                    title: Text(
                      c.code,
                      style: TextStyle(color: AppColors.textPrimaryLight),
                    ),
                    subtitle: Text(
                      c.name,
                      style: TextStyle(color: AppColors.textSecondaryCool),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: AppColors.brandPrimary)
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