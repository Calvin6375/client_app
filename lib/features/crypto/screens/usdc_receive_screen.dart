import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/crypto/models/crypto_wallet_status.dart';
import 'package:pretium/features/crypto/models/deposit_watch_result.dart';
import 'package:pretium/features/crypto/screens/crypto_transactions_screen.dart';
import 'package:pretium/features/crypto/services/crypto_api_service.dart';
import 'package:pretium/services/home_wallet_focus.dart';
import 'package:pretium/services/wallet_balance_refresh.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/truepay_qr_code.dart';

class UsdcReceiveScreen extends StatefulWidget {
  const UsdcReceiveScreen({super.key, this.walletStatus});

  /// From GET /crypto/wallet/status after production was ensured (if needed).
  final CryptoWalletStatus? walletStatus;

  @override
  State<UsdcReceiveScreen> createState() => _UsdcReceiveScreenState();
}

class _UsdcReceiveScreenState extends State<UsdcReceiveScreen> {
  final CryptoApiService _cryptoApi = CryptoApiService();

  DepositWatchResult? _watch;
  String? _error;
  bool _loading = true;
  bool _credited = false;
  bool _haveBaseline = false;
  double _baselineUsdc = 0;
  double _displayUsdc = 0;

  StreamSubscription<DatabaseEvent>? _usdcSub;

  @override
  void initState() {
    super.initState();
    _startWatch();
  }

  @override
  void dispose() {
    _usdcSub?.cancel();
    super.dispose();
  }

  Future<void> _startWatch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var status = widget.walletStatus;
      if (status == null || status.shouldCreateMainnet) {
        status = await _cryptoApi.ensureProductionWallet();
      }
      final watch = await _cryptoApi.startUsdcDepositWatch(
        network: status.preferredWatchNetwork,
      );
      if (!mounted) return;
      setState(() {
        _watch = watch;
        _loading = false;
      });
      _listenLedgerDisplay();
    } on CryptoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Failed to start USDC deposit watch';
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

  void _listenLedgerDisplay() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _usdcSub?.cancel();
    _usdcSub = FirebaseDatabase.instance
        .ref('wallet/$uid/crypto/USDC')
        .onValue
        .listen((event) {
      final value = event.snapshot.value;
      final usdc = value is num ? value.toDouble() : 0.0;
      if (!mounted) return;

      if (!_haveBaseline) {
        setState(() {
          _haveBaseline = true;
          _baselineUsdc = usdc;
          _displayUsdc = usdc;
        });
        return;
      }

      final creditedNow = !_credited && usdc > _baselineUsdc + 0.000001;
      setState(() {
        _displayUsdc = usdc;
        if (creditedNow) _credited = true;
      });
      if (creditedNow) {
        unawaited(_goHomeWithUsdcWallet());
      }
    });
  }

  Future<void> _goHomeWithUsdcWallet() async {
    try {
      await _cryptoApi.getBalance();
      await _cryptoApi.getTransactions(limit: 10);
    } catch (_) {}
    await WalletBalanceRefresh.afterSuccessfulTransaction();
    if (!mounted) return;
    HomeWalletFocus.showCryptoWallet(currency: 'USDC');
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.home,
      (route) => false,
    );
  }

  Future<void> _copyAddress(String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Top Up USDC'),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transactions',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const CryptoTransactionsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _startWatch,
        color: primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CardBlockShimmer(),
              )
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _startWatch)
            else if (_watch != null)
              _DepositContent(
                watch: _watch!,
                displayUsdc: _displayUsdc,
                credited: _credited,
                onCopy: _copyAddress,
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _DepositContent extends StatelessWidget {
  const _DepositContent({
    required this.watch,
    required this.displayUsdc,
    required this.credited,
    required this.onCopy,
  });

  final DepositWatchResult watch;
  final double displayUsdc;
  final bool credited;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Only send USDC on ${watch.networkLabel}. Sending on another network may result in lost funds.',
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _StatusBanner(
          credited: credited,
          usdc: displayUsdc,
          networkLabel: watch.networkLabel,
        ),
        const SizedBox(height: 24),
        Center(
          child: TruePayQrCode(
            data: watch.address,
            size: 248,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Send USDC to',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: SelectableText(
            watch.address,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => onCopy(watch.address),
          icon: const Icon(Icons.copy),
          label: const Text('Copy address'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Network',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.hub_outlined, size: 20, color: primary),
              const SizedBox(width: 10),
              Text(
                watch.networkLabel,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'This address is reused for your account. After you send, the app waits for the ledger — it does not scan the chain.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.credited,
    required this.usdc,
    required this.networkLabel,
  });

  final bool credited;
  final double usdc;
  final String networkLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final tone = credited ? colors.success : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          if (credited)
            Icon(Icons.check_circle_rounded, color: tone)
          else
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: tone,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credited ? 'Deposit received' : 'Waiting for deposit…',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  credited
                      ? 'USDC ${usdc.toStringAsFixed(2)} is on your ledger display.'
                      : 'Send $networkLabel USDC. Your balance updates when the backend credits you.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
