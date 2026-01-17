// First, add this to your pubspec.yaml:
// dependencies:
//   intasend_flutter: ^latest_version

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pretium/features/topup/services/intasend_service.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/repositories/user_repository.dart';
import 'package:pretium/services/firebase_payment_service.dart';
import 'package:pretium/services/order_service.dart';
import 'package:pretium/core/constants/app_colors.dart';

// Top Up main screen composed of smaller widgets
class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();

  final WalletRepository _walletRepository = WalletRepository();
  final OrderService _orderService = OrderService();
  final UserRepository _userRepository = UserRepository();

  bool _hideBalance = false;
  double _fiatBalance = 0.00;
  double _cryptoBalance = 0.00;
  String _selectedCurrency = 'USD';
  bool _isProcessingPayment = false;
  bool _isLoadingBalance = false;

  // IntaSend configuration
  static const String intaSendPublicKey ='ISPubKey_live_c2dbd636-a9a5-4a90-bdb8-dc7e7c7401a2';
  static const bool isTestMode = false;


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
        // Keep selected currency for payment processing
        _selectedCurrency = fiatWallet?.currencyCode ?? 'USD';
      });
      
      debugPrint('TopUpPage - State updated: Fiat=$_fiatBalance, Crypto=$_cryptoBalance');
    } catch (e) {
      debugPrint('Failed to load wallet balances on TopUpPage: $e');
      // Set default values on error
      if (!mounted) return;
      setState(() {
        _fiatBalance = 0.0;
        _cryptoBalance = 0.0;
        _selectedCurrency = 'USD';
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

  // FIXED: Using the official IntaSend Flutter plugin
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

    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0) {
      print('❌ Validation failed: Invalid amount: $amount');
      _showError('Please enter a valid amount');
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
          // Create order in Firestore
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await _orderService.createOrder(
                userId: user.uid,
                amount: amount,
                currency: _selectedCurrency,
                orderType: 'topup',
                metadata: {
                  'paymentId': paymentId,
                  'checkoutUrl': checkoutUrl,
                },
              );
              print('✅ Order created in Firestore');
            }
          } catch (e) {
            print('⚠️ Failed to create order: $e');
            // Don't block the payment flow if order creation fails
          }
          
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

  void _showPaymentLaunchedDialog(String checkoutUrl, String paymentId, String? message) {
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
                  const Expanded(
                    child: Text(
                      'IntaSend checkout is ready!',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
    return Scaffold(
      backgroundColor: AppColors.backgroundDeepNavy, // Deep navy #0F172A
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent for dark theme
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Topup', style: TextStyle(color: AppColors.textPrimaryLight)),
        actions: [
          IconButton(
            icon: Icon(
              _hideBalance ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textSecondaryCool,
            ),
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
          ),
          IconButton(
            icon: Icon(Icons.more_horiz, color: AppColors.textSecondaryCool),
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
                color: AppColors.backgroundDeepNavy, // Deep navy background
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
                    onPaymentPressed: _processIntaSendPayment,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Balance', style: TextStyle(color: AppColors.textSecondaryCool)),
        const SizedBox(height: 12),
        if (isLoading)
          SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(
              color: AppColors.brandPrimary,
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
                        color: AppColors.textPrimaryLight,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'USD',
                      style: TextStyle(
                        color: AppColors.textSecondaryCool,
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
                color: AppColors.surfaceVariantDark,
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
                        color: AppColors.textPrimaryLight,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'USDT',
                      style: TextStyle(
                        color: AppColors.textSecondaryCool,
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
      case 'UGX':
        return 'USh';
      case 'TZS':
        return 'TSh';
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
    
    return Card(
      elevation: 0,
      color: AppColors.surfaceDark, // Dark slate card #1E293B
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set amount',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'How much would you like to top up?',
              style: TextStyle(color: AppColors.textSecondaryCool),
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
                    border: Border.all(color: AppColors.surfaceVariantDark),
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.backgroundDeepNavy,
                  ),
                  child: DropdownButton<String>(
                    value: selectedCurrency,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    dropdownColor: AppColors.surfaceDark,
                    style: TextStyle(
                      color: AppColors.textPrimaryLight,
                    ),
                    items: ['USD', 'KES', 'UGX', 'TZS', 'EUR', 'GBP']
                        .map((currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(
                                currency,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryLight,
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
                      color: AppColors.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
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
                  backgroundColor: AppColors.brandPrimary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiatOptionCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final bool isProcessing;
  final VoidCallback onPaymentPressed;

  const _FiatOptionCard({
    required this.emailController,
    required this.firstNameController,
    required this.lastNameController,
    required this.isProcessing,
    required this.onPaymentPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceDark, // Dark slate card #1E293B
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: AppColors.brandPrimary),
                const SizedBox(width: 8),
                Text(
                  'Fiat Option',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pay with IntaSend using your card or mobile money',
              style: TextStyle(color: AppColors.textSecondaryCool),
            ),
            const SizedBox(height: 16),

            // IntaSend checkout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isProcessing 
                      ? AppColors.textTertiary 
                      : AppColors.brandPrimary, // Dark teal button
                  foregroundColor: AppColors.backgroundDeepNavy, // Dark navy text on teal
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isProcessing ? null : onPaymentPressed,
                icon: isProcessing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.backgroundDeepNavy,
                          ),
                        ),
                      )
                    : Icon(Icons.payment, color: AppColors.backgroundDeepNavy),
                label: Text(
                  isProcessing ? 'Processing...' : 'TopUp',
                  style: TextStyle(
                    color: AppColors.backgroundDeepNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
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
    return Card(
      elevation: 0,
      color: AppColors.surfaceDark, // Dark slate card #1E293B
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.currency_bitcoin, color: AppColors.brandPrimary),
                const SizedBox(width: 8),
                Text(
                  'Crypto Option',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Send cryptocurrency to these addresses',
              style: TextStyle(color: AppColors.textSecondaryCool),
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
                  color: AppColors.backgroundDeepNavy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceVariantDark),
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
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          data['network']!,
                          style: TextStyle(
                            color: AppColors.textSecondaryCool,
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
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceVariantDark),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['address']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: AppColors.textPrimaryLight,
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
                                color: AppColors.brandPrimary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.copy, size: 16, color: AppColors.brandPrimary),
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Instructions',
                        style: TextStyle(
                          color: Colors.blue[700],
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
                      color: Colors.blue[600],
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
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