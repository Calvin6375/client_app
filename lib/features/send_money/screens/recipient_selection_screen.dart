import 'package:flutter/material.dart';
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where would you send the money?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                borderRadius: BorderRadius.circular(30),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: isSelected ? primaryColor : Colors.grey.shade600),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
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
