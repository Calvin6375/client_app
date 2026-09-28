import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_profile_qr.dart';

class UserSettingsState {
  const UserSettingsState({
    this.profileQr,
    this.loadingQr = false,
  });

  final SafariTapProfileQr? profileQr;
  final bool loadingQr;

  UserSettingsState copyWith({
    SafariTapProfileQr? profileQr,
    bool? loadingQr,
  }) {
    return UserSettingsState(
      profileQr: profileQr ?? this.profileQr,
      loadingQr: loadingQr ?? this.loadingQr,
    );
  }
}

class UserSettingsNotifier extends AutoDisposeNotifier<UserSettingsState> {
  @override
  UserSettingsState build() => const UserSettingsState();

  Future<void> loadProfileQr() async {
    if (state.loadingQr) return;
    state = state.copyWith(loadingQr: true);
    try {
      final qr = await ref.read(safariTapPayApiProvider).getProfileQr();
      state = state.copyWith(profileQr: qr, loadingQr: false);
    } catch (_) {
      state = state.copyWith(loadingQr: false);
    }
  }
}

final userSettingsProvider =
    AutoDisposeNotifierProvider<UserSettingsNotifier, UserSettingsState>(
  UserSettingsNotifier.new,
);
