import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/crypto/models/deposit_watch_result.dart';
import 'package:pretium/features/crypto/screens/crypto_transactions_screen.dart';
import 'package:pretium/features/crypto/services/crypto_api_service.dart';
import 'package:pretium/services/home_wallet_focus.dart';
import 'package:pretium/services/wallet_balance_refresh.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/truepay_qr_code.dart';

class CryptoDepositNetwork {
  const CryptoDepositNetwork({
    required this.asset,
    required this.networkLabel,
    this.address,
    this.usesUsdcWatch = false,
  });

  final String asset;
  final String networkLabel;
  final String? address;
  final bool usesUsdcWatch;

  static const tabs = <CryptoDepositNetwork>[
    CryptoDepositNetwork(
      asset: 'USDT',
      networkLabel: 'Tron Network',
      address: 'TGkPQsmAhRVh51bEj961EUavP3BjZqEnBb',
    ),
    CryptoDepositNetwork(
      asset: 'USDC',
      networkLabel: 'Avalanche C-Chain',
      usesUsdcWatch: true,
    ),
    CryptoDepositNetwork(
      asset: 'BNB',
      networkLabel: 'BNB Smart Chain',
      address: '0xe421b816e5664a4ecd514956db132762b4e82e8d',
    ),
  ];
}

class CryptoDepositPage extends StatefulWidget {
  const CryptoDepositPage({super.key, this.initialAsset = 'USDT'});

  final String initialAsset;

  @override
  State<CryptoDepositPage> createState() => _CryptoDepositPageState();
}

class _CryptoDepositPageState extends State<CryptoDepositPage> {
  late int _tab;
  final CryptoApiService _cryptoApi = CryptoApiService();

  DepositWatchResult? _watch;
  String? _watchError;
  bool _watchLoading = false;
  bool _watchStarted = false;
  bool _credited = false;
  bool _haveBaseline = false;
  double _baselineUsdc = 0;
  double _displayUsdc = 0;
  StreamSubscription<DatabaseEvent>? _usdcSub;

  @override
  void initState() {
    super.initState();
    final wanted = widget.initialAsset.trim().toUpperCase();
    final index = CryptoDepositNetwork.tabs.indexWhere((t) => t.asset == wanted);
    _tab = index >= 0 ? index : 0;
    if (CryptoDepositNetwork.tabs[_tab].usesUsdcWatch) {
      _ensureUsdcWatch();
    }
  }

  @override
  void dispose() {
    _usdcSub?.cancel();
    super.dispose();
  }

  CryptoDepositNetwork get _current => CryptoDepositNetwork.tabs[_tab];

  void _selectTab(int index) {
    setState(() => _tab = index);
    if (CryptoDepositNetwork.tabs[index].usesUsdcWatch) {
      _ensureUsdcWatch();
    }
  }

  Future<void> _ensureUsdcWatch() async {
    if (_watchStarted && _watch != null) return;
    _watchStarted = true;
    setState(() {
      _watchLoading = true;
      _watchError = null;
    });
    try {
      final watch = await _cryptoApi.prepareUsdcTopUp();
      if (!mounted) return;
      setState(() {
        _watch = watch;
        _watchLoading = false;
      });
      _listenUsdcLedger();
    } on CryptoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _watchError = e.message ?? 'Failed to start USDC deposit watch';
        _watchLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _watchError = e.toString();
        _watchLoading = false;
      });
    }
  }

  void _listenUsdcLedger() {
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

  Future<void> _copy(String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied')),
    );
  }

  Future<void> _retryWatch() async {
    _watchStarted = false;
    await _ensureUsdcWatch();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Crypto Deposit'),
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _NetworkTabs(
            selected: _tab,
            onSelected: _selectTab,
          ),
          const SizedBox(height: 20),
          if (_current.usesUsdcWatch)
            _UsdcWatchBody(
              loading: _watchLoading,
              error: _watchError,
              watch: _watch,
              displayUsdc: _displayUsdc,
              credited: _credited,
              onRetry: _retryWatch,
              onCopy: _copy,
            )
          else
            _StaticDepositBody(
              network: _current,
              onCopy: _copy,
            ),
        ],
      ),
    );
  }
}

class _NetworkTabs extends StatelessWidget {
  const _NetworkTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < CryptoDepositNetwork.tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _NetworkTab(
                label: CryptoDepositNetwork.tabs[i].asset,
                selected: selected == i,
                primary: primary,
                onTap: () => onSelected(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NetworkTab extends StatelessWidget {
  const _NetworkTab({
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? (isDark ? AppColors.backgroundDeepNavy : Colors.white)
                : colors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _UsdcWatchBody extends StatelessWidget {
  const _UsdcWatchBody({
    required this.loading,
    required this.error,
    required this.watch,
    required this.displayUsdc,
    required this.credited,
    required this.onRetry,
    required this.onCopy,
  });

  final bool loading;
  final String? error;
  final DepositWatchResult? watch;
  final double displayUsdc;
  final bool credited;
  final VoidCallback onRetry;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CardBlockShimmer(),
      );
    }
    if (error != null) {
      return Column(
        children: [
          const SizedBox(height: 24),
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    }
    if (watch == null) {
      return const SizedBox.shrink();
    }
    return _DepositLayout(
      asset: 'USDC',
      address: watch!.address,
      networkLabel: watch!.networkLabel,
      waiting: !credited,
      credited: credited,
      statusDetail: credited
          ? 'USDC ${displayUsdc.toStringAsFixed(2)} is on your ledger display.'
          : 'Send ${watch!.networkLabel} USDC. Your balance updates when the backend credits you.',
      footnote:
          'This address is reused for your account. After you send, the app waits for the ledger — it does not scan the chain.',
      onCopy: onCopy,
    );
  }
}

class _StaticDepositBody extends StatelessWidget {
  const _StaticDepositBody({
    required this.network,
    required this.onCopy,
  });

  final CryptoDepositNetwork network;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    return _DepositLayout(
      asset: network.asset,
      address: network.address ?? '',
      networkLabel: network.networkLabel,
      waiting: false,
      credited: false,
      statusDetail: 'Send only ${network.asset} on ${network.networkLabel}.',
      footnote:
          'Copy the address or scan the QR from an external wallet. Use this network only.',
      onCopy: onCopy,
    );
  }
}

class _DepositLayout extends StatelessWidget {
  const _DepositLayout({
    required this.asset,
    required this.address,
    required this.networkLabel,
    required this.waiting,
    required this.credited,
    required this.statusDetail,
    required this.footnote,
    required this.onCopy,
  });

  final String asset;
  final String address;
  final String networkLabel;
  final bool waiting;
  final bool credited;
  final String statusDetail;
  final String footnote;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final tone = credited ? colors.success : primary;

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
                  'Only send $asset on $networkLabel. Sending on another network may result in lost funds.',
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
              else if (waiting)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: tone),
                )
              else
                Icon(Icons.qr_code_2, color: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credited
                          ? 'Deposit received'
                          : waiting
                              ? 'Waiting for deposit…'
                              : 'Scan or copy to deposit',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusDetail,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(child: TruePayQrCode(data: address, size: 248)),
        const SizedBox(height: 24),
        Text(
          'Send $asset to',
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
            address,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: address.isEmpty ? null : () => onCopy(address),
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
                networkLabel,
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
          footnote,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
