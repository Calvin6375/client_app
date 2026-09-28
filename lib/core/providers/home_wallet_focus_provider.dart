import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/services/home_wallet_focus.dart';

class HomeWalletFocusNotifier extends Notifier<HomeWalletFocusRequest?> {
  @override
  HomeWalletFocusRequest? build() => null;

  void showCryptoWallet({String currency = 'USDC'}) {
    state = HomeWalletFocusRequest(
      walletTab: 1,
      cryptoCurrency: currency.toUpperCase(),
    );
  }

  HomeWalletFocusRequest? take() {
    final pending = state;
    state = null;
    return pending;
  }
}

final homeWalletFocusProvider =
    NotifierProvider<HomeWalletFocusNotifier, HomeWalletFocusRequest?>(
  HomeWalletFocusNotifier.new,
);

class DashboardNavState {
  const DashboardNavState({
    this.selectedIndex = 0,
    this.selectedTab = 0,
    this.focusCryptoCurrency,
  });

  final int selectedIndex;
  final int selectedTab;
  final String? focusCryptoCurrency;

  DashboardNavState copyWith({
    int? selectedIndex,
    int? selectedTab,
    String? focusCryptoCurrency,
    bool clearFocusCurrency = false,
  }) {
    return DashboardNavState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      selectedTab: selectedTab ?? this.selectedTab,
      focusCryptoCurrency: clearFocusCurrency
          ? null
          : (focusCryptoCurrency ?? this.focusCryptoCurrency),
    );
  }
}

class DashboardNavNotifier extends Notifier<DashboardNavState> {
  @override
  DashboardNavState build() => const DashboardNavState();

  void selectIndex(int index) {
    state = state.copyWith(selectedIndex: index);
  }

  void selectTab(int tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void applyPendingFocus() {
    final focus = ref.read(homeWalletFocusProvider.notifier).take();
    if (focus == null) return;
    state = state.copyWith(
      selectedTab: focus.walletTab,
      focusCryptoCurrency: focus.cryptoCurrency,
    );
  }
}

final dashboardNavProvider =
    NotifierProvider<DashboardNavNotifier, DashboardNavState>(
  DashboardNavNotifier.new,
);
