import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/features/transactions/screens/transaction_detail_page.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/services/transactions_service.dart';

class PlaceholderTransactions extends StatefulWidget {
  const PlaceholderTransactions({super.key});

  @override
  State<PlaceholderTransactions> createState() => _PlaceholderTransactionsState();
}

class _PlaceholderTransactionsState extends State<PlaceholderTransactions> {
  final TransactionsService _transactionsService = TransactionsService();
  TransactionsResponse? _transactionsResponse;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = DashboardSessionCache.instance.copyRecentTransactionsIfFresh();
    if (cached != null) {
      _transactionsResponse = cached;
      _isLoading = false;
      return;
    }
    _loadTransactions();
  }

  /// Call this from the parent (e.g. pull-to-refresh) to reload transactions.
  Future<void> refreshTransactions() async {
    await _loadTransactions(forceNetwork: true);
  }

  Future<void> _loadTransactions({bool forceNetwork = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (!forceNetwork) {
      final cached = DashboardSessionCache.instance.copyRecentTransactionsIfFresh();
      if (cached != null) {
        if (mounted) {
          setState(() {
            _transactionsResponse = cached;
            _isLoading = false;
            _error = null;
          });
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _transactionsService.getTransactions(limit: 5);
      if (mounted) {
        DashboardSessionCache.instance.recordTransactions(response);
        setState(() {
          _transactionsResponse = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _SkeletonList();
    }

    if (_isLoading) {
      return const _SkeletonList();
    }

    if (_error != null) {
      return _ErrorTransactions(error: _error!, onRetry: _loadTransactions);
    }

    if (_transactionsResponse == null || 
        _transactionsResponse!.transactions.isEmpty) {
      return const _EmptyTransactions();
    }

    final transactions = _transactionsResponse!.transactions;
    final colors = AppColors.getThemeColors(context);

    return Column(
      children: transactions.map((transaction) {
        final title = transaction.title ??
                     (transaction.isDebit ? 'Sent' : 'Received');
        final subtitle = transaction.subtitle ?? 
                        transaction.description ?? 
                        (transaction.currency ?? '');
        final amount = transaction.amount;
        final currency = transaction.currency ?? 'KES';
        final isDebit = transaction.isDebit;

        return ListTile(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => TransactionDetailPage(transaction: transaction),
              ),
            );
          },
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
            style: TextStyle(color: colors.textPrimary),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary),
          ),
          trailing: Text(
            '${isDebit ? '-' : '+'}$currency ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isDebit ? colors.error : colors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
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

class _ErrorTransactions extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  
  const _ErrorTransactions({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Text(
            'Failed to load transactions',
            style: TextStyle(color: colors.error),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
