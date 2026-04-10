import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/send_money/screens/add_recipient_screen.dart';

enum RecipientType { people, mySelf }

class RecipientSelectionScreen extends StatefulWidget {
  final VoidCallback onNext;
  const RecipientSelectionScreen({super.key, required this.onNext});

  @override
  State<RecipientSelectionScreen> createState() => _RecipientSelectionScreenState();
}

class _RecipientSelectionScreenState extends State<RecipientSelectionScreen> {
  RecipientType _selectedType = RecipientType.people;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final colors = AppColors.getThemeColors(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where would you send the money?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary, // Theme-aware text
            ),
          ),
          const SizedBox(height: 24),
          _RecipientOptionCard(
            icon: Icons.people_outline,
            title: 'People',
            subtitle: 'Send money to one of the contact lists I have.',
            isSelected: _selectedType == RecipientType.people,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddRecipientScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _RecipientOptionCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'My Self',
            subtitle: 'Withdraw the balance of money to my local bank.',
            isSelected: _selectedType == RecipientType.mySelf,
            onTap: () => setState(() => _selectedType = RecipientType.mySelf),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _selectedType == RecipientType.mySelf ? widget.onNext : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecipientOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark 
              ? AppColors.surfaceDark // Dark slate for dark mode
              : Colors.white.withOpacity(0.9), // Translucent white for light mode
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? primaryColor 
                : (isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? primaryColor : colors.textTertiary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryColor),
          ],
        ),
      ),
    );
  }
}
