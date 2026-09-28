import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/service_providers.dart';

class LoginFlowState {
  const LoginFlowState({
    this.isLoading = false,
    this.biometricLoginAvailable = false,
    this.biometricDeviceSupported = false,
    this.biometricIcon = Icons.fingerprint,
  });

  final bool isLoading;
  final bool biometricLoginAvailable;
  final bool biometricDeviceSupported;
  final IconData biometricIcon;

  LoginFlowState copyWith({
    bool? isLoading,
    bool? biometricLoginAvailable,
    bool? biometricDeviceSupported,
    IconData? biometricIcon,
  }) {
    return LoginFlowState(
      isLoading: isLoading ?? this.isLoading,
      biometricLoginAvailable:
          biometricLoginAvailable ?? this.biometricLoginAvailable,
      biometricDeviceSupported:
          biometricDeviceSupported ?? this.biometricDeviceSupported,
      biometricIcon: biometricIcon ?? this.biometricIcon,
    );
  }
}

class LoginFlowNotifier extends AutoDisposeNotifier<LoginFlowState> {
  @override
  LoginFlowState build() {
    Future<void>(loadBiometricAvailability);
    return const LoginFlowState();
  }

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  Future<void> loadBiometricAvailability() async {
    final session = ref.read(biometricSessionProvider);
    final deviceSupported = await session.hasUsableBiometrics();
    final available = await session.canUseBiometricLogin();
    final icon = await session.preferredBiometricIcon();
    state = state.copyWith(
      biometricDeviceSupported: deviceSupported,
      biometricLoginAvailable: available,
      biometricIcon: icon,
    );
  }
}

final loginFlowProvider =
    AutoDisposeNotifierProvider<LoginFlowNotifier, LoginFlowState>(
  LoginFlowNotifier.new,
);

class RegisterFlowNotifier extends AutoDisposeNotifier<bool> {
  @override
  bool build() => false;

  void setSubmitting(bool value) => state = value;
}

final registerFlowProvider =
    AutoDisposeNotifierProvider<RegisterFlowNotifier, bool>(
  RegisterFlowNotifier.new,
);

class ForgotPasswordFlowState {
  const ForgotPasswordFlowState({
    this.isLoading = false,
    this.sentNeutralSuccess = false,
  });

  final bool isLoading;
  final bool sentNeutralSuccess;

  ForgotPasswordFlowState copyWith({
    bool? isLoading,
    bool? sentNeutralSuccess,
  }) {
    return ForgotPasswordFlowState(
      isLoading: isLoading ?? this.isLoading,
      sentNeutralSuccess: sentNeutralSuccess ?? this.sentNeutralSuccess,
    );
  }
}

class ForgotPasswordFlowNotifier
    extends AutoDisposeNotifier<ForgotPasswordFlowState> {
  @override
  ForgotPasswordFlowState build() => const ForgotPasswordFlowState();

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void markSent() {
    state = state.copyWith(sentNeutralSuccess: true);
  }
}

final forgotPasswordFlowProvider = AutoDisposeNotifierProvider<
    ForgotPasswordFlowNotifier, ForgotPasswordFlowState>(
  ForgotPasswordFlowNotifier.new,
);
