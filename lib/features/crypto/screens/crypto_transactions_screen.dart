import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/crypto/models/crypto_transaction.dart';
import 'package:pretium/features/crypto/services/crypto_api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CryptoTransactionsScreen extends StatefulWidget {
  const CryptoTransactionsScreen({super.key});

  @override
  State<CryptoTransactionsScreen> createState() => _CryptoTransactionsScreenState();
}

class _CryptoTransactionsScreenState extends State<CryptoTransactionsScreen> {
  final CryptoApiService _cryptoApi = CryptoApiService();

  List<CryptoTransaction> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _cryptoApi.getTransactions(limit: 50);
      if (!mounted) return;
      setState(() {
        _transactions = list;
        _loading = false;
      });
    } on CryptoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openTxHash(String? hash) async {
    if (hash == null || hash.isEmpty) return;
    final uri = Uri.parse('https://basescan.org/tx/$hash');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('USDC Transactions'),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        color: primary,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 48),
                      Center(child: Text(_error!, textAlign: TextAlign.center)),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _loadTransactions,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : _transactions.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('No USDC transactions yet')),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          return _TransactionTile(
                            transaction: tx,
                            onTapHash: () => _openTxHash(tx.txHash),
                          );
                        },
                      ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.onTapHash});

  final CryptoTransaction transaction;
  final VoidCallback onTapHash;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    IconData icon;
    Color iconColor;
    if (transaction.isPending) {
      icon = Icons.hourglass_top;
      iconColor = Colors.orange;
    } else if (transaction.isFailed) {
      icon = Icons.error_outline;
      iconColor = Colors.red;
    } else if (transaction.isDeposit) {
      icon = Icons.arrow_downward;
      iconColor = Colors.green;
    } else {
      icon = Icons.arrow_upward;
      iconColor = primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.displayTitle,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (transaction.createdAt != null)
                  Text(
                    _formatDate(transaction.createdAt!),
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (transaction.txHash != null && transaction.txHash!.isNotEmpty)
            IconButton(
              icon: Icon(Icons.open_in_new, color: colors.textSecondary, size: 20),
              onPressed: onTapHash,
              tooltip: 'View on explorer',
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
