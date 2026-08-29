import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/auth/widgets/phone_number_field.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_bank.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/utils/firebase_utils.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/currency_logo.dart';

/// Single Send Money form: balance card, method, amount chips, recipient fields.
class SendMoneyFormScreen extends StatefulWidget {
  const SendMoneyFormScreen({
    super.key,
    required this.onContinue,
    required this.onUpdate,
    required this.initialDetails,
    this.isValidating = false,
  });

  final VoidCallback onContinue;
  final ValueChanged<TransactionDetails> onUpdate;
  final TransactionDetails initialDetails;
  final bool isValidating;

  @override
  State<SendMoneyFormScreen> createState() => _SendMoneyFormScreenState();
}

class _SendMoneyFormScreenState extends State<SendMoneyFormScreen> {
  static const _quickAmounts = [500.0, 1000.0, 2500.0, 5000.0, 10000.0];

  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _walletRepository = WalletRepository();

  PaymentMethod _method = PaymentMethod.mobileMoney;
  double _balance = 0;
  bool _loadingBalance = true;
  List<SafariTapBank> _banks = const [];
  bool _loadingBanks = false;
  String? _selectedBankCode;
  String _countryCode = '254';

  static const _dialCodes = [
    '254',
    '256',
    '255',
    '250',
    '233',
    '234',
    '27',
    '44',
    '91',
    '1',
  ];

  @override
  void initState() {
    super.initState();
    _method = widget.initialDetails.paymentMethod;

    if (widget.initialDetails.amountToSend > 0) {
      _amountCtrl.text = _formatAmount(widget.initialDetails.amountToSend);
    }
    _fullNameCtrl.text = widget.initialDetails.recipientFullName;
    _accountNumberCtrl.text = widget.initialDetails.recipientAccountNumber ?? '';
    _selectedBankCode = widget.initialDetails.recipientBankCode;

    _hydratePhone(widget.initialDetails.recipientPhoneNumber);

    _amountCtrl.addListener(_emitUpdate);
    _fullNameCtrl.addListener(_emitUpdate);
    _phoneCtrl.addListener(_emitUpdate);
    _accountNumberCtrl.addListener(_emitUpdate);

    _loadBalance();
    if (_method == PaymentMethod.bank) _loadBanks();
  }

  void _hydratePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);

    final sorted = [..._dialCodes]..sort((a, b) => b.length.compareTo(a.length));
    for (final code in sorted) {
      if (digits.startsWith(code) && digits.length > code.length + 5) {
        _countryCode = code;
        _phoneCtrl.text = digits.substring(code.length);
        return;
      }
    }
    if (digits.startsWith('0') && digits.length >= 9) {
      _countryCode = '254';
      _phoneCtrl.text = digits.substring(1);
      return;
    }
    _phoneCtrl.text = digits;
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_emitUpdate);
    _fullNameCtrl.removeListener(_emitUpdate);
    _phoneCtrl.removeListener(_emitUpdate);
    _accountNumberCtrl.removeListener(_emitUpdate);
    _amountCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _accountNumberCtrl.dispose();
    super.dispose();
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  double get _amount {
    final raw = _amountCtrl.text.replaceAll(',', '').trim();
    return double.tryParse(raw) ?? 0;
  }

  Future<void> _loadBalance() async {
    if (!isFirebaseInitialized()) {
      if (mounted) setState(() => _loadingBalance = false);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingBalance = false);
      return;
    }
    try {
      final wallet =
          await _walletRepository.getWalletBalance(user.uid, currency: 'KES');
      if (!mounted) return;
      setState(() {
        _balance = wallet?.balance ?? 0;
        _loadingBalance = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _loadBanks() async {
    if (_banks.isNotEmpty || _loadingBanks) return;
    setState(() => _loadingBanks = true);
    try {
      final banks = await SafariTapPayApiService().listBanks();
      if (!mounted) return;
      setState(() {
        _banks = banks;
        if (_selectedBankCode != null &&
            !banks.any((b) => b.code == _selectedBankCode)) {
          _selectedBankCode = null;
        }
        _loadingBanks = false;
      });
      _emitUpdate();
    } catch (_) {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  void _selectMethod(PaymentMethod method) {
    if (_method == method) return;
    setState(() => _method = method);
    if (method == PaymentMethod.bank) _loadBanks();
    _emitUpdate();
  }

  void _applyQuickAmount(double value) {
    _amountCtrl.text = _formatAmount(value);
    _amountCtrl.selection = TextSelection.collapsed(offset: _amountCtrl.text.length);
    _emitUpdate();
  }

  bool get _needsPhone =>
      _method == PaymentMethod.mobileMoney || _method == PaymentMethod.truePay;

  Future<void> _pickFromContacts() async {
    try {
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts permission is required to pick a recipient'),
          ),
        );
        return;
      }

      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      if (contact == null || !mounted) return;

      final name = contact.displayName?.trim() ?? '';
      if (name.isNotEmpty) {
        _fullNameCtrl.text = name;
      }

      if (contact.phones.isNotEmpty) {
        final phone = contact.phones.first;
        _applyPhoneFromContact(phone.normalizedNumber ?? phone.number);
      } else {
        _emitUpdate();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open contacts')),
      );
    }
  }

  void _applyPhoneFromContact(String raw) {
    setState(() => _hydratePhone(raw));
    _emitUpdate();
  }

  SafariTapBank? get _selectedBank {
    if (_selectedBankCode == null) return null;
    for (final bank in _banks) {
      if (bank.code == _selectedBankCode) return bank;
    }
    return null;
  }

  void _emitUpdate() {
    final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final fullPhone =
        phoneDigits.isEmpty ? '' : '$_countryCode$phoneDigits';

    widget.onUpdate(
      TransactionDetails(
        amountToSend: _amount,
        fromCurrency: 'KES',
        amountToReceive: _amount,
        toCurrency: 'KES',
        paymentMethod: _method,
        recipientFullName: _fullNameCtrl.text,
        recipientPhoneNumber: fullPhone,
        recipientMobileNetwork: '',
        recipientBankName: _selectedBank?.name,
        recipientAccountNumber: _accountNumberCtrl.text,
        recipientBankCode: _selectedBankCode,
        verifiedBeneficiaryName: widget.initialDetails.verifiedBeneficiaryName,
      ),
    );
    setState(() {});
  }

  bool get _canContinue {
    if (_amount <= 0) return false;
    final nameOk = _fullNameCtrl.text.trim().isNotEmpty;
    final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final phoneOk = phoneDigits.length >= 7;

    switch (_method) {
      case PaymentMethod.mobileMoney:
      case PaymentMethod.truePay:
        return nameOk && phoneOk;
      case PaymentMethod.bank:
        return nameOk &&
            (_selectedBankCode?.isNotEmpty ?? false) &&
            _accountNumberCtrl.text.trim().isNotEmpty;
    }
  }

  void _onContinue() {
    if (!_formKey.currentState!.validate()) return;
    if (!_canContinue) return;
    if (_amount > _balance && _balance > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance. Available: KES ${_balance.toStringAsFixed(2)}',
          ),
        ),
      );
      return;
    }
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _BalanceCard(
                  balance: _balance,
                  loading: _loadingBalance,
                ),
                const SizedBox(height: 24),
                Text(
                  'Select Method',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _MethodTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'SafariTap wallet',
                  selected: _method == PaymentMethod.truePay,
                  onTap: () => _selectMethod(PaymentMethod.truePay),
                ),
                const SizedBox(height: 10),
                _MethodTile(
                  icon: Icons.phone_android_rounded,
                  title: 'Mobile Money',
                  selected: _method == PaymentMethod.mobileMoney,
                  onTap: () => _selectMethod(PaymentMethod.mobileMoney),
                ),
                const SizedBox(height: 10),
                _MethodTile(
                  icon: Icons.account_balance_rounded,
                  title: 'Bank Transfer',
                  selected: _method == PaymentMethod.bank,
                  onTap: () => _selectMethod(PaymentMethod.bank),
                ),
                const SizedBox(height: 24),
                Text(
                  'Amount (KES)',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _fieldDecoration(
                    context,
                    hint: '0',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                          (value ?? '').replaceAll(',', ''),
                        ) ??
                        0;
                    if (amount <= 0) return 'Enter an amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in _quickAmounts)
                      _AmountChip(
                        label: chip >= 1000
                            ? '${(chip / 1000).toStringAsFixed(chip % 1000 == 0 ? 0 : 1)}k'
                            : chip.toStringAsFixed(0),
                        selected: _amount == chip,
                        onTap: () => _applyQuickAmount(chip),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  _method == PaymentMethod.bank
                      ? 'Recipient details'
                      : _method == PaymentMethod.truePay
                          ? 'SafariTap recipient'
                          : 'Mobile Money Number',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _fullNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: _fieldDecoration(
                    context,
                    hint: 'Full name',
                    suffixIcon: IconButton(
                      tooltip: 'Pick from contacts',
                      onPressed: _pickFromContacts,
                      icon: Icon(
                        Icons.contacts_rounded,
                        color: primary,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                if (_needsPhone) ...[
                  PhoneNumberField(
                    phoneController: _phoneCtrl,
                    initialCountryCode: _countryCode,
                    lockCountryCode: false,
                    onCountryCodeChanged: (code) {
                      if (_countryCode == code) return;
                      setState(() => _countryCode = code);
                      _emitUpdate();
                    },
                    primaryColor: primary,
                    labelColor: colors.textSecondary,
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
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBankCode,
                    items: _banks
                        .map(
                          (bank) => DropdownMenuItem<String>(
                            value: bank.code,
                            child: Text(bank.name),
                          ),
                        )
                        .toList(),
                    onChanged: _loadingBanks
                        ? null
                        : (value) {
                            setState(() => _selectedBankCode = value);
                            _emitUpdate();
                          },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Select a bank';
                      }
                      return null;
                    },
                    isExpanded: true,
                    hint: _loadingBanks
                        ? const ShimmerBusyIndicator(width: 100, height: 12)
                        : const Text('Select bank'),
                    dropdownColor: isDark ? colors.surface : Colors.white,
                    style: TextStyle(color: colors.textPrimary, fontSize: 16),
                    decoration: _fieldDecoration(context, hint: 'Select bank'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _accountNumberCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.textPrimary),
                    decoration:
                        _fieldDecoration(context, hint: 'Account number'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Account number is required';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed:
                    (_canContinue && !widget.isValidating) ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primary.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: widget.isValidating
                    ? const ShimmerBusyIndicator(
                        width: 96,
                        height: 14,
                        onPrimary: true,
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    String? hint,
    Widget? suffixIcon,
  }) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final fill = isDark
        ? colors.surface.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor =
        isDark ? colors.border.withValues(alpha: 0.5) : const Color(0xFFE5E7EB);

    OutlineInputBorder border([Color? color]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: color ?? borderColor),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.textTertiary),
      filled: true,
      fillColor: fill,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: border(),
      enabledBorder: border(),
      focusedBorder: border(primary),
      errorBorder: border(colors.error),
      focusedErrorBorder: border(colors.error),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.loading});

  final double balance;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A),
            primary.withValues(alpha: 0.35),
            const Color(0xFF111827),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const ShimmerBusyIndicator(width: 140, height: 28, onPrimary: true)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatKes(balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'KES',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              const CurrencyLogo(code: 'KES', size: 18),
              const SizedBox(width: 8),
              Text(
                'Send from your KES wallet in Kenya',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatKes(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final reverseIndex = whole.length - i;
      buf.write(whole[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) buf.write(',');
    }
    return '${buf.toString()}.${parts[1]}';
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: isDark ? 0.16 : 0.10)
                : (isDark ? colors.surface : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? primary
                  : (isDark
                      ? colors.border.withValues(alpha: 0.45)
                      : const Color(0xFFE5E7EB)),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? primary.withValues(alpha: 0.18)
                      : (isDark
                          ? colors.background
                          : const Color(0xFFF1F5F9)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? primary : colors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected ? primary : colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? primary : colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? primary
                : (isDark ? colors.surface : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : colors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
