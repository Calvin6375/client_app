// Multi-step "Direct fiat deposit" flow (country → method → details → review → receipt).
// Styling uses AppColors / Theme to match the rest of Pretium.
// Confirm creates a server order via PaymentService.createDirectTopup (callable).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/services/payment_service.dart';

/// Route pushed from TopUp — direct bank / mobile-money style fiat deposit wizard.
class DirectFiatDepositScreen extends StatefulWidget {
  const DirectFiatDepositScreen({
    super.key,
    required this.fiatBalance,
    required this.walletCurrencyCode,
  });

  final double fiatBalance;
  final String walletCurrencyCode;

  @override
  State<DirectFiatDepositScreen> createState() => _DirectFiatDepositScreenState();
}

class _DepositCountry {
  const _DepositCountry({
    required this.name,
    required this.currencyName,
    required this.code,
    required this.flagEmoji,
  });

  final String name;
  final String currencyName;
  final String code;
  final String flagEmoji;
}

class _DepositMethodOption {
  const _DepositMethodOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.feePercent,
    required this.arrivalHint,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final double? feePercent; // null = no percentage fee
  final String arrivalHint;
}

class _MobileProvider {
  const _MobileProvider({required this.id, required this.name});

  final String id;
  final String name;
}

class _DirectFiatDepositScreenState extends State<DirectFiatDepositScreen> {
  static const _countries = <_DepositCountry>[
    _DepositCountry(name: 'Nigeria', currencyName: 'Nigerian Naira', code: 'NGN', flagEmoji: '🇳🇬'),
    _DepositCountry(name: 'Kenya', currencyName: 'Kenyan Shilling', code: 'KES', flagEmoji: '🇰🇪'),
    _DepositCountry(name: 'Uganda', currencyName: 'Ugandan Shilling', code: 'UGX', flagEmoji: '🇺🇬'),
    _DepositCountry(name: 'Tanzania', currencyName: 'Tanzanian Shilling', code: 'TZS', flagEmoji: '🇹🇿'),
    _DepositCountry(name: 'Ethiopia', currencyName: 'Ethiopian Birr', code: 'ETB', flagEmoji: '🇪🇹'),
    _DepositCountry(name: 'Burundi', currencyName: 'Burundian Franc', code: 'BIF', flagEmoji: '🇧🇮'),
  ];

  static const _methods = <_DepositMethodOption>[
    _DepositMethodOption(
      id: 'mobile_money',
      title: 'Mobile Money',
      subtitle: 'Instant deposit via MTN, Airtel, or similar',
      icon: Icons.smartphone_rounded,
      feePercent: 0.015,
      arrivalHint: 'Within 5 minutes',
    ),
    _DepositMethodOption(
      id: 'bank_transfer',
      title: 'Bank Transfer',
      subtitle: 'Transfer from your local bank account',
      icon: Icons.account_balance_rounded,
      feePercent: 0,
      arrivalHint: '',
    ),
    _DepositMethodOption(
      id: 'debit_card',
      title: 'Debit Card',
      subtitle: 'Secure payment via Mastercard / Visa',
      icon: Icons.credit_card_rounded,
      feePercent: 0.02,
      arrivalHint: 'Within 10 minutes',
    ),
  ];

  int _step = 0;
  bool _showReceipt = false;
  bool _submittingDirectTopup = false;

  _DepositCountry? _country;
  _DepositMethodOption? _method;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _bankAccountCtrl = TextEditingController();

  String _detailPayoutChoice = 'bank_transfer'; // secondary toggle on details step

  /// Selected mobile network (mobile money only); keyed by stable id for dropdown.
  String? _selectedMobileProviderId;

  // Generated after confirm
  String _receiptId = '';
  DateTime _receiptTime = DateTime.now();
  String _maskedAccount = '';

  void _onDetailsFieldsChanged() {
    if (!mounted || _step != 2) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onDetailsFieldsChanged);
    _phoneCtrl.addListener(_onDetailsFieldsChanged);
    _bankNameCtrl.addListener(_onDetailsFieldsChanged);
    _bankAccountCtrl.addListener(_onDetailsFieldsChanged);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onDetailsFieldsChanged);
    _phoneCtrl.removeListener(_onDetailsFieldsChanged);
    _bankNameCtrl.removeListener(_onDetailsFieldsChanged);
    _bankAccountCtrl.removeListener(_onDetailsFieldsChanged);
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    super.dispose();
  }

  /// E.164-style dial codes for supported wallet currencies (matches selected country).
  static String _dialCodeForCurrency(String? currencyCode) {
    switch (currencyCode) {
      case 'NGN':
        return '+234';
      case 'KES':
        return '+254';
      case 'UGX':
        return '+256';
      case 'TZS':
        return '+255';
      case 'ETB':
        return '+251';
      case 'BIF':
        return '+257';
      default:
        return '+';
    }
  }

  static List<_MobileProvider> _mobileProvidersFor(String? currencyCode) {
    switch (currencyCode) {
      case 'NGN':
        return const [
          _MobileProvider(id: 'mtn_ng', name: 'MTN'),
          _MobileProvider(id: 'airtel_ng', name: 'Airtel'),
          _MobileProvider(id: 'glo', name: 'Glo'),
          _MobileProvider(id: '9mobile', name: '9mobile'),
        ];
      case 'KES':
        return const [
          _MobileProvider(id: 'safaricom', name: 'Safaricom (M-Pesa)'),
          _MobileProvider(id: 'airtel_ke', name: 'Airtel'),
          _MobileProvider(id: 'telkom_ke', name: 'Telkom'),
        ];
      case 'UGX':
        return const [
          _MobileProvider(id: 'mtn_ug', name: 'MTN'),
          _MobileProvider(id: 'airtel_ug', name: 'Airtel'),
        ];
      case 'TZS':
        return const [
          _MobileProvider(id: 'vodacom', name: 'Vodacom (M-Pesa)'),
          _MobileProvider(id: 'airtel_tz', name: 'Airtel'),
          _MobileProvider(id: 'tigo', name: 'Tigo'),
          _MobileProvider(id: 'halotel', name: 'Halotel'),
        ];
      case 'ETB':
        return const [
          _MobileProvider(id: 'telebirr', name: 'Telebirr'),
          _MobileProvider(id: 'cbe_birr', name: 'CBE Birr'),
          _MobileProvider(id: 'mpesa_et', name: 'M-Pesa'),
        ];
      case 'BIF':
        return const [
          _MobileProvider(id: 'lumitel', name: 'Lumitel'),
          _MobileProvider(id: 'econet', name: 'Econet Leo'),
          _MobileProvider(id: 'onatel', name: 'Onatel'),
        ];
      default:
        return const [];
    }
  }

  void _syncMobileProviderSelection() {
    final list = _mobileProvidersFor(_country?.code);
    if (list.isEmpty) {
      _selectedMobileProviderId = null;
      return;
    }
    final current = _selectedMobileProviderId;
    if (current == null || !list.any((p) => p.id == current)) {
      _selectedMobileProviderId = list.first.id;
    }
  }

  String _selectedMobileProviderName() {
    final id = _selectedMobileProviderId;
    if (id == null) return '—';
    for (final p in _mobileProvidersFor(_country?.code)) {
      if (p.id == id) return p.name;
    }
    return '—';
  }

  double get _amountParsed => double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

  double get _feeAmount {
    if (_method == null || _method!.feePercent == null) return 0;
    return _amountParsed * (_method!.feePercent!);
  }

  double get _total => _amountParsed + _feeAmount;

  String _estimatedArrivalDisplay() {
    final m = _method;
    if (m == null) return '—';
    final h = m.arrivalHint.trim();
    if (h.isEmpty) return '—';
    return h;
  }

  String _maskedBankAccountForReview() {
    final raw = _bankAccountCtrl.text.replaceAll(RegExp(r'\s'), '');
    if (raw.length < 4) return '—';
    final tail = raw.substring(raw.length - 4);
    return '••••$tail';
  }

  String _payoutChipLabel(_DepositMethodOption m) {
    final hint = m.arrivalHint.trim();
    if (hint.isEmpty) return m.title;
    return '${m.title} · $hint';
  }

  /// Same rules as [_nextFromDetails]; drives Continue enabled state on the details step.
  bool get _canContinueFromDetails {
    if (_amountParsed <= 0) return false;
    if (_method?.id == 'bank_transfer') {
      if (_bankNameCtrl.text.trim().isEmpty) return false;
      final acct = _bankAccountCtrl.text.replaceAll(RegExp(r'\s'), '');
      if (acct.length < 4) return false;
    }
    if (_method?.id == 'mobile_money') {
      final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 6) return false;
      final providers = _mobileProvidersFor(_country?.code);
      if (providers.isNotEmpty &&
          (_selectedMobileProviderId == null || !providers.any((p) => p.id == _selectedMobileProviderId))) {
        return false;
      }
    }
    return true;
  }

  void _goBack() {
    if (_showReceipt) {
      Navigator.of(context).pop();
      return;
    }
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _close() => Navigator.of(context).pop();

  void _nextFromCountry() {
    if (_country == null) return;
    setState(() => _step = 1);
  }

  void _nextFromMethod() {
    if (_method == null) return;
    _detailPayoutChoice = _method!.id;
    setState(() {
      _step = 2;
      if (_method!.id == 'mobile_money') {
        _syncMobileProviderSelection();
        _bankNameCtrl.clear();
        _bankAccountCtrl.clear();
      } else {
        _selectedMobileProviderId = null;
      }
    });
  }

  void _nextFromDetails() {
    if (_amountParsed <= 0) {
      _snack('Please enter a valid amount');
      return;
    }
    if (_method?.id == 'bank_transfer') {
      if (_bankNameCtrl.text.trim().isEmpty) {
        _snack('Please enter your bank name');
        return;
      }
      final acct = _bankAccountCtrl.text.replaceAll(RegExp(r'\s'), '');
      if (acct.length < 4) {
        _snack('Please enter a valid account number');
        return;
      }
    }
    if (_method?.id == 'mobile_money') {
      final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 6) {
        _snack('Please enter a valid mobile number');
        return;
      }
      final providers = _mobileProvidersFor(_country?.code);
      if (providers.isNotEmpty && (_selectedMobileProviderId == null || !providers.any((p) => p.id == _selectedMobileProviderId))) {
        _snack('Please select a mobile provider');
        return;
      }
    }
    setState(() => _step = 3);
  }

  /// E.164-style number when the phone field has digits (mobile money required; bank optional SMS).
  String? _phoneE164ForDirectTopup() {
    final dial = _dialCodeForCurrency(_country?.code);
    final nat = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (nat.isEmpty) return null;
    return '$dial$nat';
  }

  String? _noteForDirectTopup() {
    final method = _method;
    if (method == null) return null;
    final code = _country?.code ?? '';
    final totalStr = _formatMoney(_total, code);
    switch (method.id) {
      case 'bank_transfer':
        return 'Direct deposit $totalStr — Bank transfer (${_bankNameCtrl.text.trim()})';
      case 'mobile_money':
        return 'Direct deposit $totalStr — Mobile money (${_selectedMobileProviderName()})';
      default:
        return 'Direct deposit $totalStr — ${method.title}';
    }
  }

  /// Mirrors every row on the Review deposit screen for the Cloud Function `metadata` field.
  Map<String, dynamic> _metadataForDirectTopup() {
    final code = _country?.code ?? '';
    final review = <String, dynamic>{
      'paymentMethod': _method?.title ?? '',
      'paymentMethodId': _method?.id ?? '',
      'country': _country?.name ?? '',
      'countryCode': code,
      'currencyLabel': _country != null ? '${_country!.code} (${_country!.currencyName})' : '',
      'phone': _phoneDisplayLine(),
      'processingFee': _feeAmount,
      'processingFeeFormatted': _formatMoney(_feeAmount, code),
      'depositAmount': _amountParsed,
      'depositAmountFormatted': _formatMoney(_amountParsed, code),
      'totalDue': _total,
      'totalDueFormatted': _formatMoney(_total, code),
      'estimatedArrival': _estimatedArrivalDisplay(),
    };
    if (_method?.id == 'mobile_money') {
      review['mobileProvider'] = _selectedMobileProviderName();
      review['mobileProviderId'] = _selectedMobileProviderId ?? '';
    }
    if (_method?.id == 'bank_transfer') {
      review['bankName'] = _bankNameCtrl.text.trim();
      final raw = _bankAccountCtrl.text.replaceAll(RegExp(r'\s'), '');
      if (raw.length >= 4) {
        review['accountLast4'] = raw.substring(raw.length - 4);
      }
      review['accountNumberMasked'] = _maskedBankAccountForReview();
    }
    return <String, dynamic>{
      'flow': 'direct_fiat_deposit',
      'review': review,
      'clientWalletCurrency': widget.walletCurrencyCode,
      'clientFiatBalance': widget.fiatBalance,
    };
  }

  void _applyMaskedAccountForReceipt() {
    if (_method?.id == 'mobile_money') {
      final nat = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      final dial = _dialCodeForCurrency(_country?.code);
      if (nat.length >= 2) {
        final tail = nat.substring(nat.length - 2);
        _maskedAccount = '$dial ••••••$tail';
      } else {
        _maskedAccount = '$dial ••••';
      }
    } else if (_method?.id == 'bank_transfer') {
      final raw = _bankAccountCtrl.text.replaceAll(RegExp(r'\s'), '');
      if (raw.length >= 4) {
        final tail = raw.substring(raw.length - 4);
        _maskedAccount = '••••••$tail';
      } else {
        _maskedAccount = '••••••••';
      }
    } else {
      _maskedAccount = '••••••••${_country?.code ?? 'XX'}';
    }
  }

  Future<void> _submitReview() async {
    if (_submittingDirectTopup) return;
    setState(() => _submittingDirectTopup = true);

    final paymentService = PaymentService();
    final result = await paymentService.createDirectTopup(
      amount: _amountParsed,
      currency: _country?.code,
      phoneNumber: _phoneE164ForDirectTopup(),
      note: _noteForDirectTopup(),
      metadata: _metadataForDirectTopup(),
      processingFee: _feeAmount,
      totalDue: _total,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() => _submittingDirectTopup = false);
      _snack(result['error']?.toString() ?? 'Could not create deposit order');
      return;
    }

    final ref = result['referenceId']?.toString();
    final order = result['orderId']?.toString();
    _receiptId = (ref != null && ref.isNotEmpty)
        ? ref
        : (order != null && order.isNotEmpty)
            ? order
            : '—';

    final createdStr = result['createdAt']?.toString();
    _receiptTime = createdStr != null ? (DateTime.tryParse(createdStr) ?? DateTime.now()) : DateTime.now();

    _applyMaskedAccountForReceipt();

    setState(() {
      _submittingDirectTopup = false;
      _showReceipt = true;
    });
  }

  String _phoneDisplayLine() {
    final dial = _dialCodeForCurrency(_country?.code);
    final nat = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (nat.isEmpty) return '—';
    return '$dial $nat';
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _formatMoney(double v, String code) {
    final abs = v.abs();
    final s = abs >= 1000 ? _withThousands(abs) : abs.toStringAsFixed((abs - abs.floor()) > 0 ? 2 : 0);
    return '$code $s';
  }

  String _withThousands(double v) {
    final parts = v.toStringAsFixed(0).split('');
    final buf = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buf.write(',');
      buf.write(parts[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_showReceipt) {
      return _buildReceiptScaffold(context, colors, primary, isDark);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back, color: colors.textPrimary),
          onPressed: _goBack,
        ),
        title: Text(
          'Direct Deposit',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _StepIndicator(step: _step, primary: primary, colors: colors),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _buildStepBody(context, colors, primary, isDark),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _buildPrimaryCta(context, colors, primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody(BuildContext context, AppThemeColors colors, Color primary, bool isDark) {
    switch (_step) {
      case 0:
        return _countryStep(colors, primary, isDark);
      case 1:
        return _methodStep(colors, primary, isDark);
      case 2:
        return _detailsStep(colors, primary, isDark);
      case 3:
        return _reviewStep(colors, primary, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _countryStep(AppThemeColors colors, Color primary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select country', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        const SizedBox(height: 6),
        Text(
          'Choose the destination country for your fiat deposit.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 20),
        ..._countries.map((c) => _selectableCard(
              selected: _country?.code == c.code,
              onTap: () => setState(() {
                _country = c;
                _phoneCtrl.clear();
                _bankNameCtrl.clear();
                _bankAccountCtrl.clear();
                _selectedMobileProviderId = null;
                if (_method?.id == 'mobile_money') {
                  _syncMobileProviderSelection();
                }
              }),
              child: Row(
                children: [
                  Text(c.flagEmoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: colors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${c.currencyName} (${c.code})', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                      ],
                    ),
                  ),
                  if (_country?.code == c.code)
                    Icon(Icons.check_circle, color: primary, size: 22),
                ],
              ),
            )),
      ],
    );
  }

  Widget _methodStep(AppThemeColors colors, Color primary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select payment method', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        const SizedBox(height: 6),
        Text(
          'Choose how you would like to deposit funds${_country != null ? ' in ${_country!.name}' : ''}.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 20),
        ..._methods.map((m) => _selectableCard(
              selected: _method?.id == m.id,
              onTap: () => setState(() => _method = m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(m.icon, color: primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: colors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(m.subtitle, style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.3)),
                      ],
                    ),
                  ),
                  if (_method?.id == m.id) Icon(Icons.check_circle, color: primary, size: 22),
                ],
              ),
            )),
        const SizedBox(height: 16),
        _infoBanner(
          colors,
          title: 'Transaction limit',
          body:
              'Daily deposit limits may apply for your account tier. Contact support if you need higher limits.',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _detailsStep(AppThemeColors colors, Color primary, bool isDark) {
    final sym = _currencySymbol(_country?.code ?? 'USD');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Deposit details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        const SizedBox(height: 6),
        Text(
          'How much would you like to deposit?',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? colors.surface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
            boxShadow: isDark ? null : [BoxShadow(color: colors.shadowLight, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Text(sym, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colors.textSecondary)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: TextStyle(color: colors.textTertiary),
                  ),
                ),
              ),
              Text(
                'Balance: ${widget.walletCurrencyCode} ${widget.fiatBalance.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_country != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? colors.surface : colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                Text(_country!.flagEmoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_country!.name, style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                      Text(
                        '${_country!.code} (${_country!.currencyName})',
                        style: TextStyle(fontSize: 13, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit_outlined, size: 18, color: colors.textTertiary),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text('Payout speed', style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _methods.where((m) => m.id != 'debit_card').map((m) {
            final sel = _detailPayoutChoice == m.id;
            return ChoiceChip(
              label: Text(_payoutChipLabel(m)),
              selected: sel,
              onSelected: (_) => setState(() {
                _detailPayoutChoice = m.id;
                _method = m;
                if (m.id == 'mobile_money') {
                  _syncMobileProviderSelection();
                  _bankNameCtrl.clear();
                  _bankAccountCtrl.clear();
                } else {
                  _selectedMobileProviderId = null;
                }
              }),
              selectedColor: primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: sel ? primary : colors.textSecondary,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
        if (_method?.id == 'bank_transfer') ...[
          const SizedBox(height: 20),
          Text(
            'Bank name',
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? colors.surface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
              boxShadow: isDark ? null : [BoxShadow(color: colors.shadowLight, blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _bankNameCtrl,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: colors.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'e.g. Commercial Bank of Ethiopia',
                hintStyle: TextStyle(color: colors.textTertiary, fontWeight: FontWeight.w400),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Account number',
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'The bank account you’re depositing from.',
            style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? colors.surface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
              boxShadow: isDark ? null : [BoxShadow(color: colors.shadowLight, blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _bankAccountCtrl,
              keyboardType: TextInputType.text,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: colors.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Enter account number',
                hintStyle: TextStyle(color: colors.textTertiary, fontWeight: FontWeight.w400),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Mobile number',
          style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          _method?.id == 'mobile_money'
              ? 'We’ll send payout updates to this number.'
              : 'Optional — used for SMS updates about this deposit.',
          style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.3),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? colors.surface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
            boxShadow: isDark ? null : [BoxShadow(color: colors.shadowLight, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Text(
                _dialCodeForCurrency(_country?.code),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              SizedBox(
                height: 32,
                child: VerticalDivider(width: 1, thickness: 1, color: colors.divider),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: colors.textPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: '7XX XXX XXX',
                    hintStyle: TextStyle(color: colors.textTertiary, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_method?.id == 'mobile_money' && _mobileProvidersFor(_country?.code).isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Mobile provider',
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Select the wallet or network for this number.',
            style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? colors.surface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
              boxShadow: isDark ? null : [BoxShadow(color: colors.shadowLight, blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedMobileProviderId != null &&
                        _mobileProvidersFor(_country?.code).any((p) => p.id == _selectedMobileProviderId)
                    ? _selectedMobileProviderId
                    : null,
                hint: Text('Select provider', style: TextStyle(color: colors.textTertiary, fontSize: 16)),
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: colors.textSecondary),
                dropdownColor: isDark ? colors.surface : Colors.white,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: colors.textPrimary),
                items: _mobileProvidersFor(_country?.code)
                    .map(
                      (p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(p.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedMobileProviderId = v),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Processing fee', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            Text(
              _method == null ? '—' : _formatMoney(_feeAmount, _country?.code ?? ''),
              style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Estimated arrival', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            Text(
              _estimatedArrivalDisplay(),
              style: TextStyle(fontWeight: FontWeight.w500, color: colors.textPrimary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewStep(AppThemeColors colors, Color primary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review deposit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withOpacity(0.12),
            ),
            child: Icon(Icons.account_balance_wallet_rounded, size: 40, color: primary),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text('You are depositing', style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '${_amountParsed.toStringAsFixed(2)} ${_country?.code ?? ''}',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
        ),
        const SizedBox(height: 24),
        _reviewRow(colors, 'Payment method', _method?.title ?? '—'),
        _reviewRow(colors, 'Country', _country?.name ?? '—'),
        _reviewRow(colors, 'Phone', _phoneDisplayLine()),
        if (_method?.id == 'mobile_money') _reviewRow(colors, 'Mobile provider', _selectedMobileProviderName()),
        if (_method?.id == 'bank_transfer') ...[
          _reviewRow(colors, 'Bank name', _bankNameCtrl.text.trim().isEmpty ? '—' : _bankNameCtrl.text.trim()),
          _reviewRow(colors, 'Account number', _maskedBankAccountForReview()),
        ],
        _reviewRow(colors, 'Processing fee', _formatMoney(_feeAmount, _country?.code ?? '')),
        _reviewRow(colors, 'Total due', _formatMoney(_total, _country?.code ?? ''), emphasize: true),
        _reviewRow(colors, 'Estimated arrival', _estimatedArrivalDisplay()),
      ],
    );
  }

  Widget _reviewRow(AppThemeColors colors, String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                fontSize: emphasize ? 15 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCta(BuildContext context, AppThemeColors colors, Color primary) {
    VoidCallback? onPressed;
    String label;

    switch (_step) {
      case 0:
        label = 'Continue';
        onPressed = _country != null ? _nextFromCountry : null;
        break;
      case 1:
        label = 'Continue';
        onPressed = _method != null ? _nextFromMethod : null;
        break;
      case 2:
        label = 'Continue';
        onPressed = _canContinueFromDetails ? _nextFromDetails : null;
        break;
      case 3:
        label = _submittingDirectTopup
            ? 'Creating order…'
            : 'Confirm · ${_formatMoney(_total, _country?.code ?? '')}';
        onPressed = _amountParsed > 0 &&
                _method != null &&
                _country != null &&
                !_submittingDirectTopup
            ? () {
                _submitReview();
              }
            : null;
        break;
      default:
        label = 'Next';
        onPressed = null;
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Theme.of(context).brightness == Brightness.dark ? colors.onPrimary : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
    );
  }

  Widget _buildReceiptScaffold(
    BuildContext context,
    AppThemeColors colors,
    Color primary,
    bool isDark,
  ) {
    final code = _country?.code ?? 'USD';
    final methodLabel = _method?.title ?? '—';
    final amountLabel = _formatMoney(_amountParsed, code);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: _close,
        ),
        title: Text(
          'Transaction Receipt',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Transfer successful',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Your deposit is being processed',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? colors.surface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                  boxShadow: isDark ? null : [BoxShadow(color: colors.shadowLight, blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Text('Total amount', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      amountLabel,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.textPrimary),
                    ),
                    Divider(height: 32, color: colors.divider),
                    _receiptRow(colors, 'Reference', _receiptId),
                    _receiptRow(colors, 'Payment method', methodLabel),
                    if (_method?.id == 'bank_transfer') ...[
                      _receiptRow(colors, 'Bank name', _bankNameCtrl.text.trim().isEmpty ? '—' : _bankNameCtrl.text.trim()),
                    ],
                    _receiptRow(
                      colors,
                      _method?.id == 'mobile_money'
                          ? 'Phone'
                          : _method?.id == 'bank_transfer'
                              ? 'Account number'
                              : 'Account',
                      _maskedAccount,
                    ),
                    if (_method?.id == 'mobile_money')
                      _receiptRow(colors, 'Mobile provider', _selectedMobileProviderName()),
                    _receiptRow(
                      colors,
                      'Date & time',
                      '${_receiptTime.year}-${_receiptTime.month.toString().padLeft(2, '0')}-${_receiptTime.day.toString().padLeft(2, '0')} · '
                      '${_receiptTime.hour.toString().padLeft(2, '0')}:${_receiptTime.minute.toString().padLeft(2, '0')}',
                    ),
                    _receiptRow(colors, 'Status', 'Processing'),
                    if (_method != null && _method!.arrivalHint.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.successLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded, size: 18, color: colors.success),
                              const SizedBox(width: 8),
                              Text(
                                'Estimated arrival: ${_method!.arrivalHint.trim()}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.success),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _infoBanner(
                colors,
                title: null,
                body: 'A confirmation SMS will be sent to your registered mobile number once the funds reach your wallet.',
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _close,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? colors.onPrimary : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(AppThemeColors colors, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(k, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
          ),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectableCard({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? primary : colors.border, width: selected ? 2 : 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _infoBanner(AppThemeColors colors, {String? title, required String body, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.infoLight.withOpacity(isDark ? 0.35 : 1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
                  const SizedBox(height: 4),
                ],
                Text(body, style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _currencySymbol(String code) {
    switch (code) {
      case 'USD':
        return '\$';
      case 'NGN':
        return '₦';
      case 'KES':
        return 'KSh';
      case 'UGX':
        return 'USh';
      case 'TZS':
        return 'TSh';
      case 'ETB':
        return 'Br';
      case 'BIF':
        return 'FBu';
      default:
        return code;
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.step,
    required this.primary,
    required this.colors,
  });

  final int step;
  final Color primary;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    const labels = ['Country', 'Method', 'Details', 'Review'];
    final onAccent = Theme.of(context).brightness == Brightness.dark ? colors.onPrimary : Colors.white;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(4, (i) {
        final done = i < step;
        final active = i == step;
        return Expanded(
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active ? primary : colors.surfaceVariant,
                  border: Border.all(color: active ? primary : colors.border, width: active ? 2 : 1),
                ),
                child: Center(
                  child: done
                      ? Icon(Icons.check, size: 18, color: onAccent)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: active ? onAccent : colors.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: done || active ? primary : colors.textTertiary,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
