// Top-up screen: fiat (IntaSend or TransFi) and crypto options.
// IntaSend: uses IntaSendService + PaymentService.createPayment (Cloud Function).
// TransFi: uses TransFiService only; standalone, no Cloud Function.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pretium/features/topup/services/intasend_service.dart';
import 'package:pretium/features/topup/services/transfi_service.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/repositories/user_repository.dart';
import 'package:pretium/services/firebase_payment_service.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/screens/direct_fiat_deposit_flow.dart';

/// Fiat codes in the Set amount dropdown; includes every [TopupDepositCountry.code] used for top-up.
const _topupFiatCurrencyCodes = <String>[
  'USD',
  'KES',
  'NGN',
  'GHS',
  'UGX',
  'TZS',
  'ETB',
  'BIF',
  'AED',
  'EUR',
  'GBP',
];

String _coerceTopupFiatCurrency(String? code) {
  final u = code?.trim().toUpperCase() ?? '';
  if (u.isNotEmpty && _topupFiatCurrencyCodes.contains(u)) return u;
  return 'USD';
}

// Top Up main screen composed of smaller widgets
class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key, this.initialDepositCountry});

  /// When set (from [SelectCountryTopUpScreen]), pre-selects that currency in Set amount and is passed to direct fiat deposit.
  final TopupDepositCountry? initialDepositCountry;

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();

  final WalletRepository _walletRepository = WalletRepository();
  final UserRepository _userRepository = UserRepository();

  bool _hideBalance = false;
  double _fiatBalance = 0.00;
  double _cryptoBalance = 0.00;
  String _selectedCurrency = 'USD';
  bool _isProcessingPayment = false;
  bool _isLoadingBalance = false;

  // IntaSend configuration — used only by "fiat topup" (intasend_service.dart).
  static const String intaSendPublicKey ='ISPubKey_live_c2dbd636-a9a5-4a90-bdb8-dc7e7c7401a2';
  static const bool isTestMode = false;

  /// Minimum Set amount for Fiat Option actions when currency is KES.
  static const double _kesFiatOptionMinimumAmount = 150;

  // TransFi configuration (standalone; does not use IntaSend or createPayment Cloud Function)
  static const String transfiPublicKey = 'pk_sandbox_ceaa4a8428d6b1968b72546891f74942952cceeb78f841ca'; // Set your TransFi PUBLIC_KEY
  static const String transfiSecretKey = 'sk_sandbox_0cfe2684654c778255b551382ce778845e2424162d46e46212ff76b282e7ceda'; // Set your TransFi SECRET_KEY
  static const String transfiPaymentLinkId = '6995b526e30aa438c5c0c8f2'; // e.g. 6995b526e30aa438c5c0c8f2


  bool _isFirebaseInitialized() {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    final country = widget.initialDepositCountry;
    if (country != null) {
      _selectedCurrency = _coerceTopupFiatCurrency(country.code);
    }
    _loadWalletBalance();
    _loadUserProfile();
  }
  
  Future<void> _loadUserProfile() async {
    if (!_isFirebaseInitialized()) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final userProfile = await _userRepository.getUserProfile(user.uid);
      if (userProfile != null && mounted) {
        // Auto-fill user data from Firestore
        _emailCtrl.text = userProfile.email;
        _firstNameCtrl.text = userProfile.firstName;
        _lastNameCtrl.text = userProfile.lastName;
      }
    } catch (e) {
      debugPrint('Failed to load user profile on TopUpPage: $e');
      // Continue without auto-filling if profile load fails
    }
  }

  Future<void> _loadWalletBalance() async {
    if (_isLoadingBalance || !_isFirebaseInitialized()) return;

    setState(() {
      _isLoadingBalance = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load both fiat (USD) and crypto (USDT) balances
      final fiatWallet = await _walletRepository.getWalletBalance(user.uid);
      var cryptoWallet = await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');
      
      // Create default USDT wallet if it doesn't exist (as a holding place)
      final cryptoWalletRef = FirebaseDatabase.instance.ref('wallet/${user.uid}/crypto/USDT');
      final cryptoSnapshot = await cryptoWalletRef.get();
      
      if (!cryptoSnapshot.exists) {
        try {
          final timestamp = DateTime.now().toIso8601String();
          await cryptoWalletRef.set({
            'balance': 0,
            'currency': 'USDT',
            'updatedAt': timestamp,
            'createdAt': timestamp,
          });
          debugPrint('TopUpPage - Created default USDT wallet for user ${user.uid}');
          
          // Reload the wallet after creating it
          cryptoWallet = await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');
        } catch (e) {
          debugPrint('TopUpPage - Failed to create default USDT wallet: $e');
          // Continue with default 0 balance if creation fails
        }
      }
      
      debugPrint('TopUpPage - Fiat wallet: ${fiatWallet?.balance ?? 0.0} ${fiatWallet?.currencyCode ?? "USD"}');
      debugPrint('TopUpPage - Crypto wallet: ${cryptoWallet?.balance ?? 0.0} ${cryptoWallet?.currencyCode ?? "USDT"}');
      
      if (!mounted) return;

      setState(() {
        _fiatBalance = fiatWallet?.balance ?? 0.0;
        _cryptoBalance = cryptoWallet?.balance ?? 0.0;
        _selectedCurrency = widget.initialDepositCountry != null
            ? _coerceTopupFiatCurrency(widget.initialDepositCountry!.code)
            : _coerceTopupFiatCurrency(fiatWallet?.currencyCode);
      });
      
      debugPrint('TopUpPage - State updated: Fiat=$_fiatBalance, Crypto=$_cryptoBalance');
    } catch (e) {
      debugPrint('Failed to load wallet balances on TopUpPage: $e');
      // Set default values on error
      if (!mounted) return;
      setState(() {
        _fiatBalance = 0.0;
        _cryptoBalance = 0.0;
        _selectedCurrency = widget.initialDepositCountry != null
            ? _coerceTopupFiatCurrency(widget.initialDepositCountry!.code)
            : 'USD';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingBalance = false;
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  void _applyQuick(double v) {
    final current =
        double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
    final next = current + v;
    _amountCtrl.text = next.toStringAsFixed(2);
    setState(() {});
  }

  double _parsedSetAmount() {
    final text = _amountCtrl.text.replaceAll(',', '').trim();
    return double.tryParse(text) ?? 0.0;
  }

  /// Fiat Option (IntaSend, TransFi, direct fiat): KES requires at least [_kesFiatOptionMinimumAmount].
  bool _meetsKesFiatOptionMinimum() {
    if (_selectedCurrency != 'KES') return true;
    return _parsedSetAmount() >= _kesFiatOptionMinimumAmount;
  }

  /// IntaSend flow: validate → create checkout (IntaSendService) → create
  /// payment record (Cloud Function) → show dialog and optionally launch URL.
  Future<void> _processIntaSendPayment() async {
    print('\n🚀 Starting IntaSend payment process...');
    print('Fiat balance: $_fiatBalance');
    print('Crypto balance: $_cryptoBalance');
    print('Selected currency: $_selectedCurrency');

    if (_amountCtrl.text.isEmpty) {
      print('❌ Validation failed: Missing amount');
      _showError('Please enter an amount');
      return;
    }
    
    // Validate that user profile data is available
    if (_emailCtrl.text.isEmpty ||
        _firstNameCtrl.text.isEmpty ||
        _lastNameCtrl.text.isEmpty) {
      print('❌ Validation failed: User profile data missing');
      _showError('User profile data is missing. Please ensure your profile is complete.');
      return;
    }

    final amount = _parsedSetAmount();
    if (amount <= 0) {
      print('❌ Validation failed: Invalid amount: $amount');
      _showError('Please enter a valid amount');
      return;
    }
    if (!_meetsKesFiatOptionMinimum()) {
      print('❌ Validation failed: KES fiat option minimum not met');
      _showError(
        'For KES, the minimum amount for fiat top-up options is KSh ${_kesFiatOptionMinimumAmount.toStringAsFixed(0)}.',
      );
      return;
    }

    print('✅ Payment validation passed');
    print('Payment details:');
    print('  Amount: $amount');
    print('  Currency: $_selectedCurrency');
    print('  Email: ${_emailCtrl.text.trim()}');
    print('  Name: ${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}');

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Create IntaSend service instance
      final intaSendService = IntaSendService(
        publicKey: intaSendPublicKey,
        isTestMode: isTestMode,
      );

      print('🔗 Initiating IntaSend checkout...');
      
      // Get user's phone number from Firestore profile
      String? userPhoneNumber;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userProfile = await _userRepository.getUserProfile(user.uid);
          userPhoneNumber = userProfile?.phoneNumber;
          if (userPhoneNumber != null && userPhoneNumber.isNotEmpty) {
            print('📱 Found user phone number from profile: $userPhoneNumber');
          } else {
            print('⚠️ No phone number found in user profile');
          }
        }
      } catch (e) {
        print('⚠️ Failed to fetch user phone number: $e');
        // Continue without phone number - it's optional
      }
      
      // Process payment using custom HTTP service
      final result = await intaSendService.processPayment(
        amount: amount,
        email: _emailCtrl.text.trim(),
        currency: _selectedCurrency,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phoneNumber: userPhoneNumber, // Pass the phone number from user profile
      );

      if (result['success']) {
        print('✅ IntaSend checkout URL created successfully');
        final checkoutUrl = result['checkout_url'];
        final paymentId = result['payment_id'];
        final launchFailed = result['launch_failed'] ?? false;
        
        if (checkoutUrl != null && paymentId != null) {
          // Order is created by createPayment Cloud Function; do not create from client.
          // Show payment launched dialog with URL for manual access if needed
          String message = result['message'] ?? 'Checkout created successfully';
          if (launchFailed) {
            message += ' (automatic launch failed - use options below)';
          }
          
          _showPaymentLaunchedDialog(checkoutUrl, paymentId, message);
        } else {
          _showError('Checkout URL not received from IntaSend');
        }
      } else {
        print('❌ IntaSend checkout failed: ${result['error']}');
        _showError(result['error'] ?? 'Payment failed');
      }

    } catch (e) {
      print('❌ Exception in payment process: $e');
      _showError('Error processing payment: $e');
    } finally {
      print('📋 Payment process completed, resetting state...');
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  /// TransFi payment flow (standalone; does not use IntaSend or Cloud Function createPayment).
  Future<void> _processTransFiPayment() async {
    if (_amountCtrl.text.isEmpty) {
      _showError('Please enter an amount');
      return;
    }
    if (_emailCtrl.text.isEmpty ||
        _firstNameCtrl.text.isEmpty ||
        _lastNameCtrl.text.isEmpty) {
      _showError('User profile data is missing. Please ensure your profile is complete.');
      return;
    }
    final amount = _parsedSetAmount();
    if (amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }
    if (!_meetsKesFiatOptionMinimum()) {
      _showError(
        'For KES, the minimum amount for fiat top-up options is KSh ${_kesFiatOptionMinimumAmount.toStringAsFixed(0)}.',
      );
      return;
    }
    if (transfiPublicKey.isEmpty || transfiSecretKey.isEmpty || transfiPaymentLinkId.isEmpty) {
      _showError('TransFi is not configured. Please set TransFi keys and payment link ID.');
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      String? userPhone;
      String? phoneCode;
      String? country;
      String? city;
      String? state;
      String? street;
      String? postalCode;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final profile = await _userRepository.getUserProfile(user.uid);
          userPhone = profile?.phoneNumber;
          country = profile?.country;
          city = profile?.city;
          state = profile?.state;
          street = profile?.streetAddress;
          postalCode = profile?.postalCode;
          // TransFi often expects +1 for US; normalize if we have country
          if (country == 'US' || country == 'USA') phoneCode = '+1';
        }
      } catch (_) {}

      final transfi = TransFiService(
        publicKey: transfiPublicKey,
        secretKey: transfiSecretKey,
      );
      final result = await transfi.createPaymentInvoice(
        paymentLinkId: transfiPaymentLinkId,
        amount: amount,
        currency: _selectedCurrency,
        email: _emailCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: userPhone,
        phoneCode: phoneCode,
        country: country,
        city: city,
        state: state,
        street: street,
        postalCode: postalCode,
      );

      if (result['success'] == true) {
        final checkoutUrl = result['checkout_url'] as String?;
        final invoiceId = result['invoiceId'] as String? ?? 'transfi-invoice';
        if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
          _showPaymentLaunchedDialog(
            checkoutUrl,
            invoiceId,
            'TransFi invoice created. Complete payment in the browser.',
            isTransFi: true,
          );
          try {
            final uri = Uri.parse(checkoutUrl);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {}
        } else {
          _showError(
            'TransFi did not return a checkout URL. '
            'Check the debug console for the API response. '
            'Ensure your payment link and keys are correct for the Create Payment Invoice API.',
          );
        }
      } else {
        _showError(result['error']?.toString() ?? 'TransFi payment failed');
      }
    } catch (e) {
      _showError('Error processing TransFi payment: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  void _openDirectFiatDepositFlow() {
    if (_selectedCurrency == 'KES') {
      if (_amountCtrl.text.trim().isEmpty) {
        _showError('Please enter an amount');
        return;
      }
      final amount = _parsedSetAmount();
      if (amount <= 0) {
        _showError('Please enter a valid amount');
        return;
      }
      if (!_meetsKesFiatOptionMinimum()) {
        _showError(
          'For KES, the minimum amount for fiat top-up options is KSh ${_kesFiatOptionMinimumAmount.toStringAsFixed(0)}.',
        );
        return;
      }
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DirectFiatDepositScreen(
          fiatBalance: _fiatBalance,
          walletCurrencyCode: _selectedCurrency,
          initialDepositCountry: widget.initialDepositCountry,
        ),
      ),
    );
  }

  void _showError(String message) {
    print('❌ Showing error dialog: $message');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              print('👍 User acknowledged error dialog');
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SuccessDialog(),
    );
  }

  void _showPaymentLaunchedDialog(String checkoutUrl, String paymentId, String? message, {bool isTransFi = false}) {
    final providerLabel = isTransFi ? 'TransFi' : 'IntaSend';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Ready'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$providerLabel checkout is ready!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (message != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(message, style: TextStyle(color: Colors.green[700]))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Please complete your payment using one of the options below:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // Payment URL section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text('Payment URL:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      checkoutUrl,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () async {
                              final intaSendService = IntaSendService(
                                publicKey: intaSendPublicKey,
                                isTestMode: isTestMode,
                              );
                              final launched = await intaSendService.launchCheckout(checkoutUrl, paymentId: paymentId);
                              if (!launched) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open payment page automatically. Please copy the URL above.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment page opened successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_browser, size: 16),
                            label: const Text('Open Page', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: checkoutUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment URL copied to clipboard!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy URL', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Mark payment as completed in Firebase
              print('✅ User confirmed payment completion');
              await FirebasePaymentService.markPaymentCompleted(
                paymentId: paymentId,
                transactionId: 'user_confirmed_${DateTime.now().millisecondsSinceEpoch}',
                paymentDetails: {
                  'completion_method': 'user_confirmation',
                  'confirmed_at': DateTime.now().toIso8601String(),
                },
              );
              
              // Show success dialog
              _showSuccess();
            },
            child: const Text('Payment Completed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: colors.background, // Theme-aware background
      appBar: AppBar(
        backgroundColor: isDark
            ? Colors.transparent  // Transparent for dark mode
            : primary.withOpacity(0.08), // Light mint tint (8% opacity) for light mode
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Topup', style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(
              _hideBalance ? Icons.visibility_off : Icons.visibility,
              color: colors.textSecondary,
            ),
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
          ),
          IconButton(
            icon: Icon(Icons.more_horiz, color: colors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance header area with both fiat and crypto balances
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _BalanceHeader(
              fiatBalance: _fiatBalance,
              cryptoBalance: _cryptoBalance,
              hidden: _hideBalance,
              isLoading: _isLoadingBalance,
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.background, // Theme-aware background
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SetAmountCard(
                    controller: _amountCtrl,
                    selectedCurrency: _selectedCurrency,
                    onQuickAdd: _applyQuick,
                    onCurrencyChanged: (currency) {
                      setState(() {
                        _selectedCurrency = currency;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _FiatOptionCard(
                    emailController: _emailCtrl,
                    firstNameController: _firstNameCtrl,
                    lastNameController: _lastNameCtrl,
                    isProcessing: _isProcessingPayment,
                    onIntaSendPressed: _processIntaSendPayment,
                    onTransFiPressed: _processTransFiPayment,
                    onDirectFiatDepositPressed: _openDirectFiatDepositFlow,
                  ),
                  const SizedBox(height: 16),
                  const _CryptoOptionCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Rest of your widget classes remain the same...
class _BalanceHeader extends StatelessWidget {
  final double fiatBalance;
  final double cryptoBalance;
  final bool hidden;
  final bool isLoading;
  const _BalanceHeader({
    required this.fiatBalance,
    required this.cryptoBalance,
    required this.hidden,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Balance', style: TextStyle(color: colors.textSecondary)),
        const SizedBox(height: 12),
        if (isLoading)
          SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(
              color: primary,
              strokeWidth: 2,
            ),
          )
        else
          Row(
            children: [
              // Fiat Balance (USD)
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hidden ? '\$ ••••' : '\$${fiatBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'USD',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 1,
                height: 45,
                color: colors.surfaceVariant,
              ),
              // Crypto Balance (USDT)
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hidden ? 'USDT ••••' : 'USDT ${cryptoBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'USDT',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SetAmountCard extends StatelessWidget {
  final TextEditingController controller;
  final String selectedCurrency;
  final void Function(double) onQuickAdd;
  final void Function(String) onCurrencyChanged;
  
  // Currency symbols mapping
  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'KES':
        return 'KSh';
      case 'NGN':
        return '₦';
      case 'GHS':
        return 'GH₵';
      case 'UGX':
        return 'USh';
      case 'TZS':
        return 'TSh';
      case 'ETB':
        return 'Br';
      case 'BIF':
        return 'FBu';
      case 'AED':
        return 'AED ';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currency;
    }
  }
  
  const _SetAmountCard({
    required this.controller,
    required this.selectedCurrency,
    required this.onQuickAdd,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currencySymbol = _getCurrencySymbol(selectedCurrency);
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? colors.surface // Dark slate for dark mode
            : Colors.white.withOpacity(0.9), // Translucent white for light mode
        borderRadius: BorderRadius.circular(16),
        border: isDark 
            ? null
            : Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              'Set amount',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'How much would you like to top up?',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Currency selector dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isDark 
                        ? colors.background 
                        : Colors.white.withOpacity(0.95),
                  ),
                  child: DropdownButton<String>(
                    value: selectedCurrency,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    dropdownColor: isDark ? colors.surface : Colors.white.withOpacity(0.95),
                    style: TextStyle(
                      color: colors.textPrimary,
                    ),
                    items: _topupFiatCurrencyCodes
                        .map((currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(
                                currency,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onCurrencyChanged(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [5, 10, 25, 50].map((e) {
                return ActionChip(
                  label: Text('$currencySymbol${e.toStringAsFixed(0)}'),
                  onPressed: () => onQuickAdd(e.toDouble()),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
  }
}

class _FiatOptionCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final bool isProcessing;
  final VoidCallback onIntaSendPressed;
  final VoidCallback onTransFiPressed;
  final VoidCallback onDirectFiatDepositPressed;

  const _FiatOptionCard({
    required this.emailController,
    required this.firstNameController,
    required this.lastNameController,
    required this.isProcessing,
    required this.onIntaSendPressed,
    required this.onTransFiPressed,
    required this.onDirectFiatDepositPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? colors.surface // Dark slate for dark mode
            : Colors.white.withOpacity(0.9), // Translucent white for light mode
        borderRadius: BorderRadius.circular(16),
        border: isDark 
            ? null
            : Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Fiat Option',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'TopUp with card or mobile money',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),

            // IntaSend button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isProcessing
                      ? colors.textTertiary
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: isDark ? colors.onPrimary : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isProcessing ? null : onIntaSendPressed,
                icon: isProcessing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? colors.onPrimary : Colors.white,
                          ),
                        ),
                      )
                    : Icon(Icons.payment, color: isDark ? colors.onPrimary : Colors.white),
                label: Text(
                  isProcessing ? 'Processing...' : 'fiat topup',
                  style: TextStyle(
                    color: isDark ? colors.onPrimary : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // TransFi button (standalone; does not use IntaSend)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
                onPressed: isProcessing ? null : onTransFiPressed,
                icon: Icon(Icons.link, size: 20, color: Theme.of(context).colorScheme.primary),
                label: Text(
                  'stable coin topup',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
                onPressed: isProcessing ? null : onDirectFiatDepositPressed,
                icon: Icon(Icons.account_balance, size: 20, color: Theme.of(context).colorScheme.primary),
                label: Text(
                  'Direct fiat deposit',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}

class _CryptoOptionCard extends StatelessWidget {
  const _CryptoOptionCard();

  // Cryptocurrency addresses
  static const Map<String, Map<String, String>> cryptoAddresses = {
    'USDT': {
      'address': 'TGkPQsmAhRVh51bEj961EUavP3BjZqEnBb',
      'network': 'Tron Network',
      'icon': '₮',
    },
    'USDC': {
      'address': 'FPJoay8fh2FpBBUM2pSmSdTrqpKepZPagGZfU6pwF2qo',
      'network': 'Solana Network',
      'icon': '🔵',
    },
    'BNB': {
      'address': '0xe421b816e5664a4ecd514956db132762b4e82e8d',
      'network': 'BNB Smart Chain',
      'icon': '🟡',
    },
  };

  void _copyToClipboard(BuildContext context, String address, String currency) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$currency address copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? colors.surface 
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: isDark 
            ? null
            : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Icon(Icons.currency_bitcoin, color: primary),
                const SizedBox(width: 8),
                Text(
                  'Direct Crypto Deposit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Send cryptocurrency to these addresses',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Cryptocurrency addresses
            ...cryptoAddresses.entries.map((entry) {
              final currency = entry.key;
              final data = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark 
                      ? colors.background 
                      : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          data['icon']!,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currency,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          data['network']!,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? colors.surface 
                            : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['address']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: colors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _copyToClipboard(
                              context,
                              data['address']!,
                              currency,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.copy, size: 16, color: primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            // Instructions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark 
                    ? primary.withOpacity(0.15)
                    : primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark 
                      ? primary.withOpacity(0.3)
                      : primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Instructions',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Copy the address for your preferred cryptocurrency\n'
                    '2. Send the exact top-up amount to the copied address\n'
                    '3. Payment will be processed automatically',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: primary, size: 56),
            ),
            const SizedBox(height: 12),
            const Text(
              'Payment Success',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Your IntaSend payment was processed successfully',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Processed',
                    style: TextStyle(color: Colors.black54),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Transaction Completed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Payment Method',
                    style: TextStyle(color: Colors.black54),
                  ),
                  SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.payment, color: Colors.white),
                    ),
                    title: Text('IntaSend Payment'),
                    subtitle: Text('Secure payment processed successfully'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}