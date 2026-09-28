import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/auth_providers.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/features/crypto/models/crypto_wallet_status.dart';
import 'package:pretium/features/crypto/models/deposit_watch_result.dart';
import 'package:pretium/features/crypto/services/crypto_api_service.dart';
import 'package:pretium/services/wallet_balance_refresh.dart';

class UsdcDepositWatchState {
  const UsdcDepositWatchState({
    this.watch,
    this.error,
    this.loading = false,
    this.credited = false,
    this.haveBaseline = false,
    this.baselineUsdc = 0,
    this.displayUsdc = 0,
  });

  final DepositWatchResult? watch;
  final String? error;
  final bool loading;
  final bool credited;
  final bool haveBaseline;
  final double baselineUsdc;
  final double displayUsdc;

  UsdcDepositWatchState copyWith({
    DepositWatchResult? watch,
    String? error,
    bool clearError = false,
    bool? loading,
    bool? credited,
    bool? haveBaseline,
    double? baselineUsdc,
    double? displayUsdc,
  }) {
    return UsdcDepositWatchState(
      watch: watch ?? this.watch,
      error: clearError ? null : (error ?? this.error),
      loading: loading ?? this.loading,
      credited: credited ?? this.credited,
      haveBaseline: haveBaseline ?? this.haveBaseline,
      baselineUsdc: baselineUsdc ?? this.baselineUsdc,
      displayUsdc: displayUsdc ?? this.displayUsdc,
    );
  }
}

class UsdcDepositWatchNotifier extends AutoDisposeNotifier<UsdcDepositWatchState> {
  StreamSubscription<DatabaseEvent>? _sub;

  @override
  UsdcDepositWatchState build() {
    ref.onDispose(() {
      _sub?.cancel();
    });
    return const UsdcDepositWatchState();
  }

  Future<void> startFromPrepare() async {
    if (state.watch != null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final watch =
          await ref.read(cryptoApiServiceProvider).prepareUsdcTopUp();
      state = state.copyWith(watch: watch, loading: false);
      _listenLedger();
    } on CryptoApiException catch (e) {
      state = state.copyWith(
        error: e.message ?? 'Failed to start USDC deposit watch',
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> startFromReceive({CryptoWalletStatus? walletStatus}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final api = ref.read(cryptoApiServiceProvider);
      var status = walletStatus;
      if (status == null || status.shouldCreateMainnet) {
        status = await api.ensureProductionWallet();
      }
      final watch = await api.startUsdcDepositWatch(
        network: status.preferredWatchNetwork,
      );
      state = state.copyWith(watch: watch, loading: false);
      _listenLedger();
    } on CryptoApiException catch (e) {
      state = state.copyWith(
        error: e.message ?? 'Failed to start USDC deposit watch',
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> retryPrepare() async {
    state = const UsdcDepositWatchState();
    await startFromPrepare();
  }

  Future<void> retryReceive({CryptoWalletStatus? walletStatus}) async {
    _sub?.cancel();
    state = const UsdcDepositWatchState();
    await startFromReceive(walletStatus: walletStatus);
  }

  void _listenLedger() {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    _sub?.cancel();
    _sub = FirebaseDatabase.instance
        .ref('wallet/$uid/crypto/USDC')
        .onValue
        .listen((event) {
      final value = event.snapshot.value;
      final usdc = value is num ? value.toDouble() : 0.0;
      if (!state.haveBaseline) {
        state = state.copyWith(
          haveBaseline: true,
          baselineUsdc: usdc,
          displayUsdc: usdc,
        );
        return;
      }
      final creditedNow =
          !state.credited && usdc > state.baselineUsdc + 0.000001;
      state = state.copyWith(
        displayUsdc: usdc,
        credited: creditedNow ? true : state.credited,
      );
    });
  }

  Future<void> acknowledgeCredit() async {
    final api = ref.read(cryptoApiServiceProvider);
    try {
      await api.getBalance();
      await api.getTransactions(limit: 10);
    } catch (_) {}
    await WalletBalanceRefresh.afterSuccessfulTransaction();
  }
}

final usdcDepositWatchProvider =
    AutoDisposeNotifierProvider<UsdcDepositWatchNotifier, UsdcDepositWatchState>(
  UsdcDepositWatchNotifier.new,
);
