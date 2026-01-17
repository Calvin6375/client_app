import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

enum PaymentMethod { truePay, mobileMoney, bank }

class PaymentMethodScreen extends StatefulWidget {
  final Function(PaymentMethod) onNext;
  const PaymentMethodScreen({super.key, required this.onNext});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.mobileMoney;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Choose your transfer type',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary, // Theme-aware text
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: [
              _buildSectionHeader(context, 'True Pay to True pay transfer'),
              _PaymentOptionCard(
                icon: Icons.send_to_mobile,
                title: 'True Pay to True pay transfer',
                subtitle: 'Use money in your account to pay for your transfer instantly. Should arrive in seconds.',
                isSelected: _selectedMethod == PaymentMethod.truePay,
                onTap: () => setState(() => _selectedMethod = PaymentMethod.truePay),
              ),
              _buildSectionHeader(context, 'Fast and easy transfer'),
              _PaymentOptionCard(
                icon: Icons.phone_android,
                title: 'Mobile Money',
                subtitle: 'Send money to a mobile money account.',
                isSelected: _selectedMethod == PaymentMethod.mobileMoney,
                onTap: () => setState(() => _selectedMethod = PaymentMethod.mobileMoney),
              ),
              _buildSectionHeader(context, 'Low cost transfer'),
              _PaymentOptionCard(
                icon: Icons.account_balance,
                title: 'Transfer to Bank Account',
                subtitle: 'Transfer money any bank account.',
                isSelected: _selectedMethod == PaymentMethod.bank,
                onTap: () => setState(() => _selectedMethod = PaymentMethod.bank),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => widget.onNext(_selectedMethod),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                'Continue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary, // Theme-aware text
        ),
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark 
              ? colors.surface // Dark slate for dark mode
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
                    color: Colors.black.withValues(alpha: 0.04),
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
                      color: colors.textPrimary, // Theme-aware text
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        subtitle,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
