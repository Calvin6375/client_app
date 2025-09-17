import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.flag, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Select currency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: currencies.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = currencies[i];
                  final isSelected = c.code == selectedCode;
                  return ListTile(
                    leading: CircleAvatar(child: Text(c.flagEmoji)),
                    title: Text('${c.code}'),
                    subtitle: Text(c.name),
                    trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
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