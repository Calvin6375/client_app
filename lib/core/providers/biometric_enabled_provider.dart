import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/service_providers.dart';

class BiometricEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref.read(biometricSessionProvider).isBiometricLoginEnabled();
  }

  Future<void> reload() async {
    state = AsyncData(
      await ref.read(biometricSessionProvider).isBiometricLoginEnabled(),
    );
  }

  void setLocal(bool enabled) {
    state = AsyncData(enabled);
  }
}

final biometricEnabledProvider =
    AsyncNotifierProvider<BiometricEnabledNotifier, bool>(
  BiometricEnabledNotifier.new,
);
