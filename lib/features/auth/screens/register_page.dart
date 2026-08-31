import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/services/auth_service.dart';
import 'package:pretium/services/notification_service.dart';
import 'package:pretium/utils/logger.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/core/constants/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/nationality_field.dart';
import '../widgets/phone_number_field.dart';
import '../data/nationalities.dart';
import '../widgets/register_header.dart';
import '../widgets/terms_checkbox.dart';
import 'package:pretium/features/auth/screens/legal_document_webview_page.dart';
import 'package:pretium/features/auth/services/registration_api_service.dart';
import 'package:pretium/features/auth/utils/phone_local_digits.dart';
import 'package:pretium/features/auth/utils/post_auth_routing.dart';
import 'package:pretium/services/auth_claims_service.dart';
import 'package:pretium/core/constants/auth_config.dart';
import 'package:pretium/widgets/app_shimmer.dart';

// Use app-level theme; no local constant color

class RegisterApp extends StatelessWidget {
  const RegisterApp({super.key});

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
  bool _privacyAccepted = false;
  bool _hasReadTerms = false;
  bool _hasReadPrivacy = false;
  bool _isSubmitting = false;
  String _selectedCountryCode = '254'; // Default to Kenya
  NationalityOption? _selectedNationality = nationalityByIsoCode('KE');

  final AuthService _authService = AuthService();
  final RegistrationApiService _registrationApiService = RegistrationApiService();
  final AuthClaimsService _authClaimsService = AuthClaimsService();

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onFormChanged);
    _lastNameController.addListener(_onFormChanged);
    _emailController.addListener(_onFormChanged);
    _passwordController.addListener(_onFormChanged);
    _phoneController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    setState(() {});
  }

  /// True when all fields are filled and terms are accepted (button becomes active).
  bool get _canSubmit {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final phoneDigits = _normalizedLocalPhoneDigits();
    final phoneOk = _selectedCountryCode == '254'
        ? kenyaMobileLocalRegex.hasMatch(phoneDigits)
        : phoneDigits.length >= 7 && phoneDigits.length <= 15;
    return firstName.isNotEmpty &&
        lastName.isNotEmpty &&
        email.isNotEmpty &&
        password.isNotEmpty &&
        phoneOk &&
        _selectedNationality != null &&
        _termsAccepted &&
        _privacyAccepted;
  }

  String _normalizedLocalPhoneDigits() {
    final raw = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (_selectedCountryCode == '254') {
      return stripKenyaLocalDigits(raw);
    }
    return raw;
  }

  Future<void> _openLegalDocument({
    required String title,
    required String url,
    required VoidCallback onRead,
  }) async {
    final read = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LegalDocumentWebViewPage(
          title: title,
          url: url,
        ),
      ),
    );
    if (!mounted) return;
    if (read == true) onRead();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasReadTerms || !_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !_hasReadTerms
                ? 'Open and scroll to the bottom of the Terms and Conditions first.'
                : 'Please accept the Terms and Conditions.',
          ),
        ),
      );
      return;
    }

    if (!_hasReadPrivacy || !_privacyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !_hasReadPrivacy
                ? 'Open and scroll to the bottom of the Privacy Policy first.'
                : 'Please accept the Privacy Policy.',
          ),
        ),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    // Local digits + dial code → E.164 (e.g. '+254742844875')
    final phoneDigits = _normalizedLocalPhoneDigits();
    final phoneNumberE164 =
        phoneDigits.isNotEmpty ? '+$_selectedCountryCode$phoneDigits' : '';

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    if (phoneNumberE164.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number.')),
      );
      return;
    }

    final nationality = _selectedNationality;
    if (nationality == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your nationality.')),
      );
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => _isSubmitting,
      setSubmitting: (value) => setState(() => _isSubmitting = value),
      action: () async {
        try {
          // Log complete registration request (matches API body except password is omitted)
          final registrationRequest = {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phoneNumberE164,
        'country': nationality.isoCode,
        'Institution': RegistrationApiService.institution,
        'Channel': RegistrationApiService.channel,
        'passwordLength': password.length,
      };
      Logger.info('🚀 ===== CREATE USER REQUEST =====');
      Logger.info('📋 Registration Data: $registrationRequest');
      Logger.info('=====================================');

      // 0) Backend creates Auth + profile (`POST /api/register` → 201).
      Logger.info('📤 Step 0: Registering customer with backend API...');
      await _registrationApiService.registerCustomer(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumberE164: phoneNumberE164,
        password: password,
        country: nationality.isoCode,
      );
      Logger.success('✅ Backend registration completed');

      // 1) Sign in with the account the backend just created — do not createUser again.
      Logger.info('📤 Step 1: Signing in with Firebase Auth...');
      final credential = await _authService.signIn(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      Logger.info('⏳ Waiting for auth token to be ready...');
      try {
        await credential.user!.getIdToken(true);
        final userType =
            await _authClaimsService.userTypeClaim(forceRefresh: true);
        Logger.info(
          '✅ Auth token is ready (userType: ${userType ?? "(missing)"})',
        );
        if (userType != AuthConfig.expectedCustomerClaim) {
          Logger.warning(
            'Expected userType "${AuthConfig.expectedCustomerClaim}" after registration, got: $userType',
          );
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        Logger.warning('⚠️ Token refresh warning: $e (continuing anyway)');
      }

      // 2) Setup notifications (profile already created by backend).
      Logger.info('📤 Step 2: Setting up notifications...');
      try {
        await NotificationService().setupNotifications(uid);
        Logger.success('✅ Notifications setup completed');
      } catch (e) {
        Logger.warning('⚠️ Failed to setup notifications: $e');
      }

      Logger.success('✅ ===== CREATE USER SUCCESS =====');
      Logger.success('   User ID: $uid');
      Logger.success('   Email: $email');
      Logger.success('==================================');

      // 3) Route by userType claim (customer stays in app; partner/admin → web dashboard)
      if (!mounted) return;
      await completeAuthAndRoute(context);
        } on RegistrationApiException catch (e) {
          Logger.error('Backend registration failed', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message)),
            );
          }
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
        }
      },
    );
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_onFormChanged);
    _lastNameController.removeListener(_onFormChanged);
    _emailController.removeListener(_onFormChanged);
    _passwordController.removeListener(_onFormChanged);
    _phoneController.removeListener(_onFormChanged);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                ),
                const SizedBox(height: 24),

                NationalityField(
                  primaryColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.primary,
                  initialValue: _selectedNationality,
                  onChanged: (option) {
                    setState(() => _selectedNationality = option);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select your nationality';
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
                // Separate Terms / Privacy boxes — each enabled after that doc is scrolled.
                TermsCheckbox(
                  termsAccepted: _termsAccepted,
                  privacyAccepted: _privacyAccepted,
                  canAcceptTerms: _hasReadTerms,
                  canAcceptPrivacy: _hasReadPrivacy,
                  onTermsTap: () => _openLegalDocument(
                    title: 'Terms of Service',
                    url: LegalDocumentWebViewPage.termsOfServiceUrl,
                    onRead: () => setState(() {
                      _hasReadTerms = true;
                      _termsAccepted = true;
                    }),
                  ),
                  onPrivacyTap: () => _openLegalDocument(
                    title: 'Privacy Policy',
                    url: LegalDocumentWebViewPage.privacyPolicyUrl,
                    onRead: () => setState(() {
                      _hasReadPrivacy = true;
                      _privacyAccepted = true;
                    }),
                  ),
                  onTermsChanged: (value) {
                    if (!_hasReadTerms) return;
                    setState(() => _termsAccepted = value ?? false);
                  },
                  onPrivacyChanged: (value) {
                    if (!_hasReadPrivacy) return;
                    setState(() => _privacyAccepted = value ?? false);
                  },
                  color: Theme.of(context).colorScheme.primary,
                ),

                const SizedBox(height: 24),
                // Create Account button - active only when all fields filled and terms accepted
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSubmit && !_isSubmitting
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: (_canSubmit && !_isSubmitting) ? _register : null,
                    child: _isSubmitting
                        ? const ShimmerBusyIndicator(
                            width: 96,
                            height: 14,
                            onPrimary: true,
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
                // Login section
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
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
    );
  }
}
