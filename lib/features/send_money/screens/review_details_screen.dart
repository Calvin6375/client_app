import 'package:flutter/material.dart';
import 'package:pretium/models/transaction_details_model.dart';

class ReviewDetailsScreen extends StatelessWidget {
  final VoidCallback onNext;
  final TransactionDetails details;
  const ReviewDetailsScreen({super.key, required this.onNext, required this.details});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review your detail transfer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildDetailsCard(
                  title: 'Transfer details',
                  children: [
                    _DetailRow(label: 'You send', value: '${details.amountToSend.toStringAsFixed(2)} ${details.fromCurrency}'),
                    const _DetailRow(label: 'Arto+ fees', value: 'Free'),
                    const _DetailRow(label: 'Payment method fees', value: 'Free'),
                    _DetailRow(label: 'You will pay', value: '${details.amountToSend.toStringAsFixed(2)} ${details.fromCurrency}', isBold: true),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailsCard(
                  title: 'Recipient details',
                  children: [
                    _buildRecipientTile(
                      details.recipientFullName,
                      details.recipientPhoneNumber,
                      '${details.amountToReceive.toStringAsFixed(2)} ${details.toCurrency}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard({required String title, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientTile(String name, String email, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const CircleAvatar(child: Text('R')),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(email, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
          const Spacer(),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? Colors.black : Colors.grey.shade600)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
