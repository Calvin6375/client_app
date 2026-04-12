import 'package:flutter/material.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/auth/widgets/phone_number_field.dart';

/// Mobile network options for the recipient currency (mobile money).
List<String> _mobileNetworksForCurrency(String currency) {
  switch (currency.toUpperCase()) {
    case 'KES':
      return ['Safaricom (M-Pesa)', 'Airtel', 'Telkom'];
    case 'UGX':
      return ['MTN', 'Airtel'];
    case 'TZS':
      return ['Vodacom (M-Pesa)', 'Airtel', 'Halotel', 'Tigo'];
    case 'NGN':
      return ['MTN', 'Airtel', 'Glo', '9mobile'];
    case 'GHS':
      return ['MTN', 'Vodafone', 'AirtelTigo'];
    case 'ETB':
      return ['Telebirr', 'CBE Birr', 'M-Pesa'];
    case 'BIF':
      return ['Lumitel', 'Econet Leo', 'Onatel'];
    case 'ZAR':
      return ['Vodacom', 'MTN', 'Cell C'];
    case 'USD':
    case 'USDT':
      return [
        'Cash App',
        'Venmo',
        'PayPal',
        'Apple Pay',
        'Google Pay',
        'Zelle',
      ];
    default:
      return ['Other'];
  }
}

/// Default dial code for "You Receive" currency (recipient country).
String _defaultDialCodeForCurrency(String currency) {
  switch (currency.toUpperCase()) {
    case 'KES':
      return '254'; // Kenya
    case 'USD':
      return '1'; // United States
    case 'NGN':
      return '234'; // Nigeria
    case 'GHS':
      return '233'; // Ghana
    case 'UGX':
      return '256'; // Uganda
    case 'TZS':
      return '255'; // Tanzania
    case 'USDT':
      return '1'; // Default to US for crypto
    case 'ZAR':
      return '27'; // South Africa
    default:
      return '254';
  }
}

class RecipientDetailsScreen extends StatefulWidget {
  final PaymentMethod paymentMethod;
  final VoidCallback onNext;
  final Function(TransactionDetails) onUpdate;
  final TransactionDetails initialDetails;

  const RecipientDetailsScreen({
    super.key,
    required this.paymentMethod,
    required this.onNext,
    required this.onUpdate,
    required this.initialDetails,
  });

  @override
  State<RecipientDetailsScreen> createState() => _RecipientDetailsScreenState();
}

class _RecipientDetailsScreenState extends State<RecipientDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _accountNumberCtrl;
  late String _selectedCountryCode;
  String? _selectedMobileNetwork;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController(text: widget.initialDetails.recipientFullName);
    _bankNameCtrl = TextEditingController(text: widget.initialDetails.recipientBankName);
    _accountNumberCtrl = TextEditingController(text: widget.initialDetails.recipientAccountNumber);

    final networkOptions = _mobileNetworksForCurrency(widget.initialDetails.toCurrency);
    final saved = widget.initialDetails.recipientMobileNetwork.trim();
    if (saved.isNotEmpty && networkOptions.contains(saved)) {
      _selectedMobileNetwork = saved;
    }

    _selectedCountryCode = _defaultDialCodeForCurrency(widget.initialDetails.toCurrency);
    final digitsOnly = widget.initialDetails.recipientPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final phoneText = digitsOnly.startsWith(_selectedCountryCode)
        ? digitsOnly.substring(_selectedCountryCode.length)
        : digitsOnly;
    _phoneCtrl = TextEditingController(text: phoneText);

    _fullNameCtrl.addListener(_onChanged);
    _phoneCtrl.addListener(_onChanged);
    _bankNameCtrl.addListener(_onChanged);
    _accountNumberCtrl.addListener(_onChanged);
  }

  bool _isFormComplete() {
    final nameOk = _fullNameCtrl.text.trim().isNotEmpty;
    final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final phoneOk = phoneDigits.length >= 7;

    switch (widget.paymentMethod) {
      case PaymentMethod.mobileMoney:
        final networkOk = _selectedMobileNetwork != null &&
            _selectedMobileNetwork!.trim().isNotEmpty;
        return nameOk && phoneOk && networkOk;
      case PaymentMethod.bank:
        final bankOk = _bankNameCtrl.text.trim().isNotEmpty &&
            _accountNumberCtrl.text.trim().isNotEmpty;
        return nameOk && phoneOk && bankOk;
      case PaymentMethod.truePay:
        return nameOk && phoneOk;
    }
  }

  void _onChanged() {
    final fullPhone = _phoneCtrl.text.trim().isEmpty
        ? ''
        : '$_selectedCountryCode${_phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '')}';
    widget.onUpdate(
      TransactionDetails(
        amountToSend: widget.initialDetails.amountToSend,
        fromCurrency: widget.initialDetails.fromCurrency,
        amountToReceive: widget.initialDetails.amountToReceive,
        toCurrency: widget.initialDetails.toCurrency,
        paymentMethod: widget.initialDetails.paymentMethod,
        recipientFullName: _fullNameCtrl.text,
        recipientPhoneNumber: fullPhone,
        recipientMobileNetwork: _selectedMobileNetwork ?? '',
        recipientBankName: _bankNameCtrl.text,
        recipientAccountNumber: _accountNumberCtrl.text,
      ),
    );
  }

  @override
  void dispose() {
    _fullNameCtrl.removeListener(_onChanged);
    _phoneCtrl.removeListener(_onChanged);
    _bankNameCtrl.removeListener(_onChanged);
    _accountNumberCtrl.removeListener(_onChanged);
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final canContinue = _isFormComplete();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipient Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary, // Theme-aware text
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildTextField(label: 'Full Name', controller: _fullNameCtrl),
                  const SizedBox(height: 24),
                  PhoneNumberField(
                    key: ValueKey(widget.initialDetails.toCurrency),
                    phoneController: _phoneCtrl,
                    initialCountryCode: _selectedCountryCode,
                    lockCountryCode: true,
                    primaryColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      if (value.trim().length < 7) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  if (widget.paymentMethod == PaymentMethod.mobileMoney) ...[
                    const SizedBox(height: 24),
                    _buildMobileNetworkDropdown(context),
                  ],
                  if (widget.paymentMethod == PaymentMethod.bank) ...[
                    const SizedBox(height: 24),
                    _buildTextField(label: 'Bank Name', controller: _bankNameCtrl),
                    const SizedBox(height: 24),
                    _buildTextField(label: 'Account Number', controller: _accountNumberCtrl),
                  ],
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canContinue ? _onContinue : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: primary,
                foregroundColor: isDark ? colors.onPrimary : Colors.white,
                disabledBackgroundColor: primary.withValues(alpha: 0.38),
                disabledForegroundColor: isDark
                    ? colors.onPrimary.withValues(alpha: 0.62)
                    : Colors.white.withValues(alpha: 0.62),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onContinue() {
    if (!_formKey.currentState!.validate()) return;
    if (widget.paymentMethod == PaymentMethod.mobileMoney &&
        (_selectedMobileNetwork == null || _selectedMobileNetwork!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mobile network provider')),
      );
      return;
    }
    widget.onNext();
  }

  Widget _buildMobileNetworkDropdown(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final options = _mobileNetworksForCurrency(widget.initialDetails.toCurrency);
    final v = _selectedMobileNetwork;
    final effectiveValue = (v != null && v.isNotEmpty && options.contains(v)) ? v : null;
    return DropdownButtonFormField<String>(
      value: effectiveValue,
      items: [
        ...options.map(
          (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
        ),
      ],
      onChanged: (v) {
        setState(() => _selectedMobileNetwork = v);
        _onChanged();
      },
      validator: (v) {
        if (widget.paymentMethod != PaymentMethod.mobileMoney) return null;
        if (v == null || v.trim().isEmpty) return 'Select a mobile network';
        return null;
      },
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: colors.textSecondary),
      dropdownColor: isDark ? colors.surface : Colors.white,
      style: TextStyle(color: colors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Mobile network provider',
        labelStyle: TextStyle(color: colors.textSecondary),
        filled: true,
        fillColor: isDark ? colors.surface : Colors.white.withValues(alpha: 0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
  }) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary),
        filled: true,
        fillColor: isDark 
            ? colors.surface
            : Colors.white.withValues(alpha: 0.9), // Translucent white for light mode
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
            ),
          ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}
