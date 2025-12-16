import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

class PlaceholderTransactions extends StatelessWidget {
  const PlaceholderTransactions({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _SkeletonList();
    }

    final txQuery =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: txQuery,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SkeletonList();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyTransactions();
        }

        final docs = snapshot.data!.docs;
        return Column(
          children:
              docs.map((doc) {
                final data = doc.data();
                final title = (data['title'] ?? 'Transaction') as String;
                final subtitle = (data['subtitle'] ?? '') as String;
                final amountRaw = data['amount'];
                double amount = 0.0;
                if (amountRaw is num) amount = amountRaw.toDouble();
                if (amountRaw is String)
                  amount = double.tryParse(amountRaw) ?? 0.0;
                final isDebit = (data['type'] ?? 'debit') == 'debit';

                final colors = AppColors.getThemeColors(context);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors.infoLight,
                    child: Icon(
                      isDebit ? Icons.call_made : Icons.call_received,
                      color: colors.primary,
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    (isDebit ? '-' : '+') + 'KES ' + amount.toStringAsFixed(2),
                    style: TextStyle(
                      color: isDebit ? colors.error : colors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Column(
      children: List.generate(
        3,
        (index) => ListTile(
          leading: CircleAvatar(backgroundColor: colors.border),
          title: Container(height: 10, color: colors.border),
          subtitle: Container(
            height: 10,
            width: 100,
            color: colors.borderLight,
          ),
          trailing: Container(
            height: 10,
            width: 60,
            color: colors.border,
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        'No recent transactions',
        style: TextStyle(color: colors.textSecondary),
      ),
    );
  }
}
