import 'package:flutter/material.dart';
import 'package:pretium/features/auth/screens/register_page.dart';
import 'package:pretium/features/auth/widgets/custom_text_field.dart';
import 'package:pretium/features/auth/widgets/wallet_icon_header.dart';
import 'package:pretium/features/auth/widgets/welcome_text_section.dart';
import 'package:pretium/features/home/screens/landing_page.dart';
import 'package:pretium/services/auth_service.dart';
import 'package:pretium/services/notification_service.dart';
import 'package:pretium/utils/logger.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  final AuthService _authService = AuthService();


  @override
  Widget build(BuildContext context) {
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
                    onPressed: () {},
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

              // Login button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      _isLoading
                          ? null
                          : () async {
                            final email = _emailController.text.trim();
                            final password = _passwordController.text;
                            if (email.isEmpty || password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter email and password'),
                                ),
                              );
                              return;
                            }

                            setState(() => _isLoading = true);
                            try {
                              final credential = await _authService.signIn(
                                email: email,
                                password: password,
                              );
                              
                              // Setup notifications after successful login
                              if (credential.user?.uid != null) {
                                try {
                                  await NotificationService()
                                      .setupNotifications(credential.user!.uid);
                                } catch (e) {
                                  Logger.warning(
                                      'Failed to setup notifications after login: $e');
                                  // Don't block login if notification setup fails
                                }
                              }
                              
                              if (!mounted) return;
                              DashboardSessionCache.instance.clear();
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LandingPage(),
                                ),
                                (route) => false,
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
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            'Login',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                ),
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
