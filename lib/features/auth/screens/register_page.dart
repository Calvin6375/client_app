import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/services/auth_service.dart';
import 'package:pretium/services/notification_service.dart';
import 'package:pretium/repositories/user_repository.dart';
import 'package:pretium/utils/logger.dart';
import 'package:pretium/core/constants/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/phone_number_field.dart';
import '../widgets/register_header.dart';
import '../widgets/terms_checkbox.dart';
import 'package:pretium/features/home/screens/landing_page.dart';

// Use app-level theme; no local constant color

class RegisterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return MaterialApp(
      title: 'Create Account',
      theme: Theme.of(context).copyWith(
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: primary, onPrimary: Colors.white),
        primaryColor: primary,
        appBarTheme: AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
      home: const RegisterPage(),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _termsAccepted = false;
  bool _isSubmitting = false;
  String _selectedCountryCode = '254'; // Default to Kenya

  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and conditions.'),
        ),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    // Get formatted phone number (country code + number, e.g., '254742844875')
    final phoneDigits = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    final phoneNumber = phoneDigits.isNotEmpty ? '$_selectedCountryCode$phoneDigits' : '';

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Log complete registration request
      final registrationRequest = {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phoneNumber.isNotEmpty ? phoneNumber : null,
        'passwordLength': password.length,
      };
      Logger.info('🚀 ===== CREATE USER REQUEST =====');
      Logger.info('📋 Registration Data: $registrationRequest');
      Logger.info('=====================================');
      
      // 1) Create user in Firebase Auth
      Logger.info('📤 Step 1: Creating user in Firebase Auth...');
      final credential = await _authService.signUp(
        email: email,
        password: password,
      );

      // 2) Wait for auth token to be ready (especially important on physical devices)
      final uid = credential.user!.uid;
      Logger.info('⏳ Waiting for auth token to be ready...');
      try {
        // Force a token refresh to ensure it's available
        await credential.user!.getIdToken(true);
        Logger.info('✅ Auth token is ready');
        
        // Small delay to ensure auth state propagates to Firestore
        // This is especially important on physical devices with network latency
        await Future.delayed(const Duration(milliseconds: 500));
        Logger.info('✅ Auth state propagation delay completed');
      } catch (e) {
        Logger.warning('⚠️ Token refresh warning: $e (continuing anyway)');
      }

      // 3) Create user profile in Firestore
      Logger.info('📤 Step 2: Creating user profile in Firestore...');
      await _userRepository.createUserProfile(
        uid: uid,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
      );
      
      // 4) Setup notifications (save FCM token)
      Logger.info('📤 Step 3: Setting up notifications...');
      try {
        await NotificationService().setupNotifications(uid);
        Logger.success('✅ Notifications setup completed');
      } catch (e) {
        Logger.warning('⚠️ Failed to setup notifications: $e');
        // Don't block registration if notification setup fails
      }
      
      Logger.success('✅ ===== CREATE USER SUCCESS =====');
      Logger.success('   User ID: $uid');
      Logger.success('   Email: $email');
      Logger.success('==================================');

      // 5) Navigate to landing page on success
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LandingPage()),
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
      Logger.error('Registration failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Scaffold(
      backgroundColor: colors.background, // Theme-aware background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: SizedBox(
              // Set minimum height to screen height minus safe area
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const SizedBox(height: 16),

                  // Back Arrow
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Header section with left alignment
                  const RegisterHeader(),
                  const SizedBox(height: 32),

                  // First Name field
                  CustomTextField(
                    controller: _firstNameController,
                    labelText: 'First Name',
                    hintText: 'Enter your first name',
                    prefixIcon: Icons.person_outline,
                    primaryColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),

                  // Last Name field
                  CustomTextField(
                    controller: _lastNameController,
                    labelText: 'Last Name',
                    hintText: 'Enter your last name',
                    prefixIcon: Icons.person_outline,
                    primaryColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),

                  // Email field
                  CustomTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    primaryColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),

                  // Phone Number field with country code selector
                  PhoneNumberField(
                    phoneController: _phoneController,
                    primaryColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    initialCountryCode: _selectedCountryCode,
                    onCountryCodeChanged: (countryCode) {
                      setState(() {
                        _selectedCountryCode = countryCode;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (value.trim().length < 7) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
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

                  const SizedBox(height: 16),
                  // Terms and conditions checkbox
                  TermsCheckbox(
                    value: _termsAccepted,
                    onChanged: (value) {
                      setState(() {
                        _termsAccepted = value!;
                      });
                    },
                    color: Theme.of(context).colorScheme.primary,
                  ),

                  const SizedBox(height: 24),
                  // Create Account button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _register,
                      child: Text(
                        _isSubmitting ? 'Creating...' : 'Create Account',
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),

                  const Expanded(
                    child: SizedBox(),
                  ), // Replace Spacer with Expanded
                  // Login section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: () => Navigator.pop(context), // Add navigation
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
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
          ),
        ),
      ),
    );
  }
}
