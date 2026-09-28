import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/repositories/user_repository.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/auth_service.dart';
import 'package:pretium/services/biometric_session_service.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/features/crypto/services/crypto_api_service.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/features/swap/services/rates_service.dart';
import 'package:pretium/features/topup/services/topup_quote_api_service.dart';
import 'package:pretium/services/countries_api_service.dart';
import 'package:pretium/features/auth/services/registration_api_service.dart';
import 'package:pretium/services/auth_claims_service.dart';
import 'package:pretium/services/notification_service.dart';
import 'package:pretium/services/transactions_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository();
});

final transactionsServiceProvider = Provider<TransactionsService>((ref) {
  return TransactionsService();
});

final biometricSessionProvider = Provider<BiometricSessionService>((ref) {
  return BiometricSessionService.instance;
});

final dashboardSessionCacheProvider = Provider<DashboardSessionCache>((ref) {
  return DashboardSessionCache.instance;
});

final safariTapPayApiProvider = Provider<SafariTapPayApiService>((ref) {
  return SafariTapPayApiService();
});

final cryptoApiServiceProvider = Provider<CryptoApiService>((ref) {
  return CryptoApiService();
});

final countriesApiProvider = Provider<CountriesApiService>((ref) {
  return CountriesApiService();
});

final topupQuoteApiProvider = Provider<TopupQuoteApiService>((ref) {
  return TopupQuoteApiService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final registrationApiServiceProvider = Provider<RegistrationApiService>((ref) {
  return RegistrationApiService();
});

final authClaimsServiceProvider = Provider<AuthClaimsService>((ref) {
  return AuthClaimsService();
});

final ratesServiceProvider = Provider<RatesService>((ref) {
  final service = RatesService();
  ref.onDispose(service.dispose);
  return service;
});
