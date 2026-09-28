import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/features/auth/providers/auth_flow_provider.dart';
import 'package:pretium/features/auth/screens/forgot_password_page.dart';
import 'package:pretium/features/auth/screens/register_page.dart';
import 'package:pretium/features/auth/widgets/custom_text_field.dart';
import 'package:pretium/features/auth/widgets/wallet_icon_header.dart';
import 'package:pretium/features/auth/widgets/welcome_text_section.dart';
import 'package:pretium/features/auth/utils/post_auth_routing.dart';
import 'package:pretium/services/auth_service.dart';
import 'package:pretium/utils/logger.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/widgets/app_shimmer.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginPage>
    with WidgetsBindingObserver {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(loginFlowProvider.notifier).loadBiometricAvailability();
    }
  }

  void _onBiometricButtonPressed() {
    if (ref.read(loginFlowProvider).isLoading) return;
    if (ref.read(loginFlowProvider).biometricLoginAvailable) {
      _signInWithBiometrics();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Biometric login is not set up yet. Sign in with your password, '
          'then enable it in Wallet Settings.',
        ),
      ),
    );
  }

  Future<void> _completeLogin(
    UserCredential credential, {
    required String email,
    required String password,
  }) async {
    if (credential.user?.uid != null) {
      try {
        await ref.read(notificationServiceProvider).setupNotifications(credential.user!.uid);
      } catch (e) {
        Logger.warning('Failed to setup notifications after login: $e');
      }
    }

    if (!mounted) return;

    await ref.read(biometricSessionProvider).maybePromptEnableAfterLogin(
      context,
      email: email,
      password: password,
    );

    if (!mounted) return;
    await ref.read(loginFlowProvider.notifier).loadBiometricAvailability();
    if (!mounted) return;
    await completeAuthAndRoute(context);
  }

  Future<void> _signInWithBiometrics() async {
    final flow = ref.read(loginFlowProvider);
    if (!flow.biometricLoginAvailable || flow.isLoading) return;

    ref.read(loginFlowProvider.notifier).setLoading(true);
    try {
      final verified = await ref.read(biometricSessionProvider).authenticate(
        reason: 'Sign in with biometrics',
      );
      if (!verified) return;

      final credentials =
          await ref.read(biometricSessionProvider).readStoredCredentials();
      if (credentials == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric login is not set up. Sign in with your password.'),
            ),
          );
        }
        return;
      }

      final credential = await ref.read(authServiceProvider).signIn(
        email: credentials.email,
        password: credentials.password,
      );

      if (!mounted) return;
      await _completeLogin(
        credential,
        email: credentials.email,
        password: credentials.password,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.getErrorMessage(e))),
        );
      }
    } catch (e) {
      Logger.error('Biometric login failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric sign-in failed. Try your password instead.'),
          ),
        );
      }
    } finally {
      if (mounted) ref.read(loginFlowProvider.notifier).setLoading(false);
    }
  }

  Future<void> _signInWithPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password')),
      );
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => ref.read(loginFlowProvider).isLoading,
      setSubmitting: (value) =>
          ref.read(loginFlowProvider.notifier).setLoading(value),
      action: () async {
        try {
          final credential = await ref.read(authServiceProvider).signIn(
            email: email,
            password: password,
          );

          if (!mounted) return;
          await _completeLogin(
            credential,
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          final message = AuthService.getErrorMessage(e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        } catch (e) {
          Logger.error('Login failed', e);
          if (!mounted) return;
          final String message;
          if (e is FirebaseAuthException) {
            message = AuthService.getErrorMessage(e);
          } else {
            message =
                'Unable to sign in. Please check your connection and try again.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(loginFlowProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Wallet icon header
              WalletIconHeader(color: Theme.of(context).colorScheme.primary),

              const SizedBox(height: 80),

              // Welcome text section
              const WelcomeTextSection(),
              const SizedBox(height: 48),

              // Email field
              CustomTextField(
                controller: _emailController,
                labelText: 'Email',
                hintText: 'Enter your email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                primaryColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // Password field
              CustomTextField(
                controller: _passwordController,
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                primaryColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // Remember Me and Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: Theme.of(context).colorScheme.primary,
                        checkColor: AppColors.getThemeColors(context).onPrimary,
                        side: BorderSide(
                          color: AppColors.getThemeColors(context).border,
                          width: 3.0,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder:
                              (context) => ForgotPasswordPage(
                                initialEmail: _emailController.text.trim(),
                              ),
                        ),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Login button + biometric shortcut
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: flow.isLoading ? null : _signInWithPassword,
                        child: flow.isLoading
                            ? const ShimmerBusyIndicator(onPrimary: true)
                            : const Text(
                                'Login',
                                style: TextStyle(fontSize: 18, color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                  if (flow.biometricDeviceSupported) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 52,
                      width: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: flow.biometricLoginAvailable
                                ? Theme.of(context).colorScheme.primary
                                : AppColors.getThemeColors(context).textTertiary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            flow.isLoading ? null : _onBiometricButtonPressed,
                        child: Icon(
                          flow.biometricIcon,
                          size: 28,
                          color: flow.biometricLoginAvailable
                              ? Theme.of(context).colorScheme.primary
                              : AppColors.getThemeColors(context).textTertiary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),


              // Sign Up text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
