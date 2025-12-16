import 'package:flutter/material.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/features/topup/services/intasend_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class WalletCard extends StatefulWidget {
  const WalletCard({super.key});

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  int _currentPage = 0;
  late final IntaSendService _service;
  Wallet? _wallet;
  bool _loading = false;
  String? _error;
  DateTime? _lastRefreshedAt;
  
  bool _isFirebaseInitialized() {
    return Firebase.apps.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _service = IntaSendService(publicKey: 'public-key-not-used-here');
    if (_isFirebaseInitialized()) {
      _refreshBalance();
      // Auto-refresh every 60s
      Future.doWhile(() async {
        await Future.delayed(const Duration(seconds: 60));
        if (!mounted) return false;
        await _refreshBalance(silent: true);
        return mounted;
      });
    }
  }

  Future<void> _refreshBalance({bool silent = false}) async {
    if (!_isFirebaseInitialized()) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      if (!silent) setState(() { _loading = true; _error = null; });
      
      // fetchWalletBalance now always returns a Wallet (default if not found)
      final latest = await _service.fetchWalletBalance(user.uid);
      if (!mounted) return;
      setState(() {
        _wallet = latest;
        _lastRefreshedAt = DateTime.now();
        _error = null; // Clear any previous errors
      });
    } catch (e) {
      // This should rarely happen now since fetchWalletBalance returns default wallet
      if (!mounted) return;
      setState(() { 
        // Only show error for unexpected exceptions (network issues, etc.)
        final errorMsg = e.toString();
        _error = errorMsg.length > 100 ? '${errorMsg.substring(0, 100)}...' : errorMsg;
        // Still set a default wallet so UI doesn't break
        _wallet ??= Wallet(currencyCode: 'KES', balance: 0.0);
      });
    } finally {
      if (!mounted) return;
      if (!silent) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = _wallet != null ? [_wallet!] : [Wallet(currencyCode: 'KES', balance: 0.0)];
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            itemCount: wallets.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return _SingleWalletCard(
                wallet: wallets[index],
                loading: _loading,
                error: _error,
                onRefresh: _refreshBalance,
                onTopUpCompleted: () async {
                  await _refreshBalance();
                },
                lastRefreshedAt: _lastRefreshedAt,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(wallets.length, (index) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SingleWalletCard extends StatelessWidget {
  final Wallet wallet;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onTopUpCompleted;
  final DateTime? lastRefreshedAt;
  const _SingleWalletCard({required this.wallet, this.loading = false, this.error, required this.onRefresh, required this.onTopUpCompleted, this.lastRefreshedAt});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withOpacity(0.95),
            primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Wallet Balance", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          if (loading)
            const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(color: Colors.white))
          else if (error != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 60),
              child: SingleChildScrollView(
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            Text(
              "${wallet.currencyCode} ${wallet.balance.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (lastRefreshedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Updated ${TimeOfDay.fromDateTime(lastRefreshedAt!).format(context)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).pushNamed(RouteNames.topup);
                    await onTopUpCompleted();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Top Up'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pushNamed(RouteNames.swap),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Swap'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh Balance',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
