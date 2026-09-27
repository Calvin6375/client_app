import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/auth/widgets/phone_number_field.dart';
import 'package:pretium/features/pay/screens/qr_scan_page.dart';
import 'package:pretium/features/safari_tap/utils/payout_error_messages.dart';
import 'package:pretium/features/safari_tap/utils/safaritap_profile_qr.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_bank.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/features/send_money/widgets/bank_picker_bottom_sheet.dart';
import 'package:pretium/features/swap/widgets/currency_picker_bottom_sheet.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/utils/firebase_utils.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/currency_logo.dart';
import 'package:pretium/widgets/money_form_widgets.dart';

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

  PaymentMethod? _method;
  String _currency = 'KES';
  double _balance = 0;
  bool _loadingBalance = true;
  final List<String> _ownedCurrencyCodes = [];
  final Map<String, double> _ownedBalances = {};
  List<SafariTapBank> _banks = const [];
  bool _loadingBanks = false;
  String? _selectedBankCode;
  String? _recipientUserId;
  bool _resolvingQr = false;
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
    // Restore prior choice when returning from review; stay unset on first open.
    _method = widget.initialDetails.paymentMethod;
    _currency = widget.initialDetails.fromCurrency.trim().isNotEmpty
        ? widget.initialDetails.fromCurrency.trim().toUpperCase()
        : 'KES';

    if (widget.initialDetails.amountToSend > 0) {
      _amountCtrl.text = _formatAmount(widget.initialDetails.amountToSend);
    }
    _fullNameCtrl.text = widget.initialDetails.recipientFullName;
    _accountNumberCtrl.text = widget.initialDetails.recipientAccountNumber ?? '';
    _selectedBankCode = widget.initialDetails.recipientBankCode;
    _recipientUserId = widget.initialDetails.recipientUserId;

    _hydratePhone(widget.initialDetails.recipientPhoneNumber);

    _amountCtrl.addListener(_emitUpdate);
    _fullNameCtrl.addListener(_emitUpdate);
    _phoneCtrl.addListener(_onPhoneEdited);
    _accountNumberCtrl.addListener(_emitUpdate);

    _loadOwnedWallets();
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
    _phoneCtrl.removeListener(_onPhoneEdited);
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

  /// Same wallet source as home / Exchange: session cache first, then
  /// `GET /api/accounts` (`data.fiat`).
  Future<void> _loadOwnedWallets() async {
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
      setState(() => _loadingBalance = true);

      final codes = <String>{};
      final balances = <String, double>{};

      // Prefer the wallets already resolved for the home wallet carousel.
      final snap = DashboardSessionCache.instance.readWalletLastKnown();
      if (snap != null) {
        for (final code in snap.availableFiatCurrencies) {
          final upper = code.toUpperCase();
          if (upper.isEmpty) continue;
          final bal = snap.fiatWallets[upper]?.balance ??
              snap.fiatWallets[code]?.balance ??
              0;
          if (bal <= 0) continue;
          codes.add(upper);
          balances[upper] = bal;
        }
      }

      // Same as Exchange: owned fiat accounts from GET /api/accounts.
      final fiat = await _walletRepository.listOwnedFiatWallets(user.uid);
      for (final e in fiat.entries) {
        final upper = e.key.toUpperCase();
        if (upper.isEmpty || e.value.balance <= 0) continue;
        codes.add(upper);
        balances[upper] = e.value.balance;
      }

      // If still empty, probe known currencies (balance > 0 only).
      if (codes.isEmpty) {
        for (final currency in const ['KES', 'USD', 'NGN', 'GHS', 'UGX']) {
          try {
            final wallet = await _walletRepository.getWalletBalance(
              user.uid,
              currency: currency,
            );
            if (wallet != null && wallet.balance > 0) {
              codes.add(currency);
              balances[currency] = wallet.balance;
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;

      // Only wallets with money are selectable / shown in the picker.
      final ordered = codes.where((c) => (balances[c] ?? 0) > 0).toList()
        ..sort((a, b) {
          if (a == 'KES') return -1;
          if (b == 'KES') return 1;
          return a.compareTo(b);
        });

      if (ordered.isEmpty) {
        setState(() => _loadingBalance = false);
        return;
      }

      if (!ordered.contains(_currency)) {
        _currency = ordered.first;
      }

      setState(() {
        _ownedCurrencyCodes
          ..clear()
          ..addAll(ordered);
        _ownedBalances
          ..clear()
          ..addAll(balances);
        _balance = _ownedBalances[_currency] ?? 0;
        _loadingBalance = false;
      });
      _emitUpdate();
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _selectWallet(String code) async {
    final upper = code.trim().toUpperCase();
    if (upper.isEmpty || upper == _currency) return;
    if (!_ownedCurrencyCodes.contains(upper)) return;

    setState(() {
      _currency = upper;
      _balance = _ownedBalances[upper] ?? 0;
      // Safari Card payouts (MM / Bank / Wallet) are KES-only.
      if (upper != 'KES') {
        // Keep method selection; continue will prompt to switch to KES.
      } else if (_countryCode != '254' &&
          (_method == PaymentMethod.mobileMoney ||
              _method == PaymentMethod.truePay)) {
        _countryCode = '254';
      }
    });
    _emitUpdate();

    if (!isFirebaseInitialized()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final wallet =
          await _walletRepository.getWalletBalance(user.uid, currency: upper);
      if (!mounted || wallet == null) return;
      setState(() {
        _balance = wallet.balance;
        _ownedBalances[upper] = _balance;
      });
    } catch (_) {}
  }

  /// Same picker sheet as Exchange (`CurrencyPickerBottomSheet`).
  void _showWalletPicker() {
    final currencies = [
      for (final code in _ownedCurrencyCodes)
        if (code.trim().isNotEmpty)
          Currency(
            code: code,
            name: CurrencyLogo.displayNameFor(code),
            flagEmoji: CurrencyLogo.emojiFor(code),
          ),
    ];
    if (currencies.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (context) => CurrencyPickerBottomSheet(
        currencies: currencies,
        selectedCode: _currency,
        onSelected: (currency) {
          // Sheet already pops itself before calling onSelected.
          _selectWallet(currency.code);
        },
      ),
    );
  }

  Future<void> _showBankPicker({ValueChanged<String>? onPicked}) async {
    if (_loadingBanks || _banks.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (context) => BankPickerBottomSheet(
        banks: _banks,
        selectedCode: _selectedBankCode,
        onSelected: (bank) {
          setState(() => _selectedBankCode = bank.code);
          onPicked?.call(bank.code);
          _emitUpdate();
        },
      ),
    );
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
    final kenyaOnly =
        method == PaymentMethod.truePay || method == PaymentMethod.mobileMoney;
    if (_method == method) {
      if (kenyaOnly && _countryCode != '254') {
        setState(() => _countryCode = '254');
        _emitUpdate();
      }
      return;
    }
    setState(() {
      _method = method;
      _recipientUserId = null;
      if (method == PaymentMethod.truePay) {
        _fullNameCtrl.clear();
      }
      // Mobile Money and SafariTap wallet are Kenya (+254) only.
      if (kenyaOnly) _countryCode = '254';
    });
    if (method == PaymentMethod.bank) _loadBanks();
    _emitUpdate();
  }

  void _applyQuickAmount(double value) {
    _amountCtrl.text = _formatAmount(value);
    _amountCtrl.selection = TextSelection.collapsed(offset: _amountCtrl.text.length);
    _emitUpdate();
  }

  bool get _needsPhone => _method == PaymentMethod.mobileMoney;

  bool get _hasScannedWalletRecipient =>
      _method == PaymentMethod.truePay &&
      (_recipientUserId?.trim().isNotEmpty ?? false) &&
      _fullNameCtrl.text.trim().isNotEmpty;

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

  void _onPhoneEdited() {
    if (_recipientUserId != null) {
      _recipientUserId = null;
    }
    _emitUpdate();
  }

  Future<void> _scanSafariTapProfileQr() async {
    if (_resolvingQr) return;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanPage(title: 'Scan SafariTap QR')),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;

    setState(() => _resolvingQr = true);
    try {
      final decodedId = parseSafariTapCustomerId(code);
      final result = await SafariTapPayApiService().validateUser(
        qrPayload: code.trim(),
        customerId: decodedId,
      );
      if (!mounted) return;
      if (result.self) {
        setState(() {
          _recipientUserId = null;
          _fullNameCtrl.clear();
          _resolvingQr = false;
        });
        _emitUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can’t send money to your own SafariTap wallet.'),
          ),
        );
        return;
      }
      final name = result.fullName.trim();
      final customerId = result.customerId.trim();
      if (!result.valid || name.isEmpty || customerId.isEmpty) {
        setState(() {
          _recipientUserId = null;
          _fullNameCtrl.clear();
          _resolvingQr = false;
        });
        _emitUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not verify this SafariTap user.')),
        );
        return;
      }
      setState(() {
        _recipientUserId = customerId;
        _fullNameCtrl.text = name;
        _resolvingQr = false;
      });
      _emitUpdate();
    } on SafariTapPayApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _recipientUserId = null;
        _fullNameCtrl.clear();
        _resolvingQr = false;
      });
      _emitUpdate();
      final message = e.statusCode == 404
          ? 'No SafariTap user found for this QR.'
          : safariTapPayoutErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recipientUserId = null;
        _fullNameCtrl.clear();
        _resolvingQr = false;
      });
      _emitUpdate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not verify this SafariTap user.')),
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
        fromCurrency: _currency,
        amountToReceive: _amount,
        toCurrency: _currency,
        paymentMethod: _method,
        recipientFullName: _fullNameCtrl.text,
        recipientPhoneNumber: fullPhone,
        recipientMobileNetwork: '',
        recipientBankName: _selectedBank?.name,
        recipientAccountNumber: _accountNumberCtrl.text,
        recipientBankCode: _selectedBankCode,
        recipientUserId: _recipientUserId,
        verifiedBeneficiaryName: widget.initialDetails.verifiedBeneficiaryName,
      ),
    );
    setState(() {});
  }

  bool get _canContinue {
    final method = _method;
    if (method == null) return false;
    if (_amount <= 0) return false;
    final nameOk = _fullNameCtrl.text.trim().isNotEmpty;
    // Local part only — country code (+254) is selected separately.
    final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final phoneOk = phoneDigits.length == 9;

    switch (method) {
      case PaymentMethod.mobileMoney:
        return nameOk && phoneOk;
      case PaymentMethod.truePay:
        return _hasScannedWalletRecipient;
      case PaymentMethod.bank:
        return nameOk &&
            (_selectedBankCode?.isNotEmpty ?? false) &&
            _accountNumberCtrl.text.trim().isNotEmpty;
    }
  }

  void _onContinue() {
    if (!_formKey.currentState!.validate()) return;
    if (!_canContinue) return;
    if (_currency != 'KES') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Send Money payouts require a KES wallet. Switch to KES to continue.',
          ),
        ),
      );
      return;
    }
    if (_method == PaymentMethod.mobileMoney && _countryCode != '254') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use a Kenyan (+254) phone number for Mobile Money or SafariTap wallet.',
          ),
        ),
      );
      return;
    }
    if (_amount > _balance && _balance > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance. Available: $_currency ${_balance.toStringAsFixed(2)}',
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

    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                MoneyBalanceCard(
                  currency: _currency,
                  balance: _balance,
                  loading: _loadingBalance,
                  onWalletTap: _ownedCurrencyCodes.isNotEmpty
                      ? _showWalletPicker
                      : null,
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
                MoneyMethodTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'SafariTap wallet',
                  selected: _method == PaymentMethod.truePay,
                  onTap: () => _selectMethod(PaymentMethod.truePay),
                ),
                const SizedBox(height: 10),
                MoneyMethodTile(
                  icon: Icons.phone_android_rounded,
                  title: 'Mobile Money',
                  selected: _method == PaymentMethod.mobileMoney,
                  onTap: () => _selectMethod(PaymentMethod.mobileMoney),
                ),
                const SizedBox(height: 10),
                MoneyMethodTile(
                  icon: Icons.account_balance_rounded,
                  title: 'Bank Transfer',
                  selected: _method == PaymentMethod.bank,
                  onTap: () => _selectMethod(PaymentMethod.bank),
                ),
                if (_currency != 'KES') ...[
                  const SizedBox(height: 10),
                  Text(
                    'Send Money requires a KES wallet for SafariTap wallet, Mobile Money, and Bank Transfer.',
                    style: TextStyle(color: colors.error, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Amount ($_currency)',
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
                  decoration: moneyFieldDecoration(
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
                      MoneyAmountChip(
                        label: chip >= 1000
                            ? '${(chip / 1000).toStringAsFixed(chip % 1000 == 0 ? 0 : 1)}k'
                            : chip.toStringAsFixed(0),
                        selected: _amount == chip,
                        onTap: () => _applyQuickAmount(chip),
                      ),
                  ],
                ),
                if (_method == PaymentMethod.truePay) ...[
                  const SizedBox(height: 24),
                  Text(
                    'SafariTap recipient',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _fullNameCtrl,
                    readOnly: true,
                    enableInteractiveSelection: false,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: moneyFieldDecoration(
                      context,
                      hint: 'Scan QR to add recipient',
                      suffixIcon: IconButton(
                        tooltip: 'Scan SafariTap QR',
                        onPressed:
                            _resolvingQr ? null : _scanSafariTapProfileQr,
                        icon: _resolvingQr
                            ? const ShimmerBusyIndicator(
                                width: 18,
                                height: 18,
                              )
                            : Icon(
                                Icons.qr_code_2_rounded,
                                color: primary,
                              ),
                      ),
                    ),
                    onTap: _resolvingQr ? null : _scanSafariTapProfileQr,
                    validator: (v) {
                      if (!_hasScannedWalletRecipient) {
                        return 'Scan a SafariTap QR to continue';
                      }
                      return null;
                    },
                  ),
                ] else if (_method != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    _method == PaymentMethod.bank
                        ? 'Recipient details'
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
                    decoration: moneyFieldDecoration(
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
                      // Mobile Money + SafariTap wallet resolve recipients as Kenya 254… numbers.
                      lockCountryCode: _method == PaymentMethod.mobileMoney,
                      onCountryCodeChanged: (code) {
                        if (_countryCode == code) return;
                        setState(() => _countryCode = code);
                        _emitUpdate();
                      },
                      primaryColor: primary,
                      labelColor: colors.textSecondary,
                      validator: (value) {
                        final digits =
                            (value ?? '').replaceAll(RegExp(r'[^\d]'), '');
                        if (digits.isEmpty) {
                          return 'Phone number is required';
                        }
                        // +254 is already selected — local mobile must be exactly 9 digits.
                        if (digits.length != 9) {
                          return 'Enter a 9-digit phone number';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    FormField<String>(
                      initialValue: _selectedBankCode,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Select a bank';
                        }
                        return null;
                      },
                      builder: (state) {
                        final selectedName = _selectedBank?.name;
                        return InkWell(
                          onTap: _loadingBanks
                              ? null
                              : () => _showBankPicker(
                                    onPicked: state.didChange,
                                  ),
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            isEmpty: selectedName == null,
                            decoration: moneyFieldDecoration(
                              context,
                              hint: 'Select bank',
                            ).copyWith(
                              errorText: state.errorText,
                              suffixIcon: _loadingBanks
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: ShimmerBusyIndicator(
                                        width: 18,
                                        height: 18,
                                      ),
                                    )
                                  : Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: colors.textSecondary,
                                    ),
                            ),
                            child: Text(
                              selectedName ?? '',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _accountNumberCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: colors.textPrimary),
                      decoration:
                          moneyFieldDecoration(context, hint: 'Account number'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Account number is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        MoneyPrimaryButton(
          label: 'Continue',
          loading: widget.isValidating,
          enabled: _canContinue && !widget.isValidating,
          onPressed: _onContinue,
        ),
      ],
    );
  }
}

