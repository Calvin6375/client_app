import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/crypto/models/crypto_wallet_status.dart';
import 'package:pretium/features/crypto/models/deposit_watch_result.dart';
import 'package:pretium/features/crypto/providers/usdc_deposit_watch_provider.dart';
import 'package:pretium/features/crypto/screens/crypto_transactions_screen.dart';
import 'package:pretium/core/providers/home_wallet_focus_provider.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/truepay_qr_code.dart';

class UsdcReceiveScreen extends ConsumerStatefulWidget {
  const UsdcReceiveScreen({super.key, this.walletStatus});

  /// From GET /crypto/wallet/status after production was ensured (if needed).
  final CryptoWalletStatus? walletStatus;

  @override
  ConsumerState<UsdcReceiveScreen> createState() => _UsdcReceiveScreenState();
}

class _UsdcReceiveScreenState extends ConsumerState<UsdcReceiveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(usdcDepositWatchProvider.notifier).startFromReceive(
            walletStatus: widget.walletStatus,
          );
    });
  }

  Future<void> _retryWatch() {
    return ref.read(usdcDepositWatchProvider.notifier).retryReceive(
          walletStatus: widget.walletStatus,
        );
  }

  Future<void> _goHomeWithUsdcWallet() async {
    await ref.read(usdcDepositWatchProvider.notifier).acknowledgeCredit();
    if (!mounted) return;
    ref.read(homeWalletFocusProvider.notifier).showCryptoWallet(currency: 'USDC');
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
    final watchState = ref.watch(usdcDepositWatchProvider);
    ref.listen(usdcDepositWatchProvider, (prev, next) {
      if (next.credited && prev?.credited != true) {
        unawaited(_goHomeWithUsdcWallet());
      }
    });
    final pending = watchState.loading ||
        (watchState.watch == null && watchState.error == null);

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
        onRefresh: _retryWatch,
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
            if (pending)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CardBlockShimmer(),
              )
            else if (watchState.error != null)
              _ErrorState(message: watchState.error!, onRetry: _retryWatch)
            else if (watchState.watch != null)
              _DepositContent(
                watch: watchState.watch!,
                displayUsdc: watchState.displayUsdc,
                credited: watchState.credited,
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
