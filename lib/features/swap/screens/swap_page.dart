import 'package:flutter/material.dart';
import 'package:pretium/features/swap/widgets/currency_picker_bottom_sheet.dart';
import 'package:pretium/features/swap/services/rates_service.dart';

class SwapPage extends StatefulWidget {
  const SwapPage({super.key});

  @override
  State<SwapPage> createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> {
  final TextEditingController _fromCtrl = TextEditingController(text: '50000');
  String _fromCurrency = 'NGN';
  String _toCurrency = 'USD';
  double _rate =
      740; // NGN per 1 USD (demo / will be overridden by RatesService)
  double _feeNgn = 200; // flat fee in NGN (demo)

  final _rates = RatesService();

  double get _fromAmountNgn =>
      double.tryParse(_fromCtrl.text.replaceAll(',', '')) ?? 0.0;
  double get _toAmountUsd => (_fromAmountNgn - _feeNgn) / _rate;

  @override
  void initState() {
    super.initState();
    // Listen to live rate updates
    _rates.ratesStream.listen((map) {
      setState(() {
        _rate = _rates.getRate('NGN', 'USD');
      });
    });
  }

  @override
  void dispose() {
    _rates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: primary,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Swap', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF2F5F8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SwapCard(
                    fromCtrl: _fromCtrl,
                    fromCurrency: _fromCurrency,
                    toCurrency: _toCurrency,
                    toAmountText: _toAmountUsd.toStringAsFixed(3),
                    onSwitch: () {
                      setState(() {
                        final tmp = _fromCurrency;
                        _fromCurrency = _toCurrency;
                        _toCurrency = tmp;
                      });
                    },
                    onPickFrom: () => _showCurrencyPicker(true),
                    onPickTo: () => _showCurrencyPicker(false),
                  ),
                  const SizedBox(height: 16),
                  _RatesAndFees(
                    rateText: '₦${_rate.toStringAsFixed(0)} = \$1',
                    feeText: '₦${_feeNgn.toStringAsFixed(0)}',
                  ),
                ],
              ),
            ),
          ),
          _SlideToConfirm(
            label: 'Slide to swap',
            onCompleted: () => _showSuccess(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showCurrencyPicker(bool isFrom) async {
    final list = const [
      Currency(code: 'NGN', name: 'Nigerian Naira', flagEmoji: '🇳🇬'),
      Currency(code: 'USD', name: 'US Dollar', flagEmoji: '🇺🇸'),
      Currency(code: 'KES', name: 'Kenyan Shilling', flagEmoji: '🇰🇪'),
      Currency(code: 'GHS', name: 'Ghanaian Cedi', flagEmoji: '🇬🇭'),
    ];
    final code = isFrom ? _fromCurrency : _toCurrency;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => CurrencyPickerBottomSheet(
            currencies: list,
            selectedCode: code,
            onSelected: (c) {
              setState(() {
                if (isFrom) {
                  _fromCurrency = c.code;
                } else {
                  _toCurrency = c.code;
                }
                // Update rate for selected pair if we support it; fallback to NGNUSD for demo
                if (_fromCurrency == 'NGN' && _toCurrency == 'USD') {
                  _rate = _rates.getRate('NGN', 'USD');
                } else if (_fromCurrency == 'USD' && _toCurrency == 'NGN') {
                  _rate = 1 / _rates.getRate('NGN', 'USD');
                } else {
                  // simple fallback demo: convert via USD if needed
                  _rate = _rates.getRate('NGN', 'USD');
                }
              });
            },
          ),
    );
  }

  void _showSuccess(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
                    'Swap Success',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You received \$${_toAmountUsd.toStringAsFixed(3)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
          ),
    );
  }
}

class _SwapCard extends StatelessWidget {
  final TextEditingController fromCtrl;
  final String fromCurrency;
  final String toCurrency;
  final String toAmountText;
  final VoidCallback onSwitch;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  const _SwapCard({
    required this.fromCtrl,
    required this.fromCurrency,
    required this.toCurrency,
    required this.toAmountText,
    required this.onSwitch,
    required this.onPickFrom,
    required this.onPickTo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: fromCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                        ),
                        onChanged: (_) => (context as Element).markNeedsBuild(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${(double.tryParse(fromCtrl.text) ?? 0) / 740}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _CurrencyDropdown(code: fromCurrency, onTap: onPickFrom),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: InkWell(
                onTap: onSwitch,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.swap_vert, color: primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "You'll receive",
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '\$$toAmountText',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CurrencyDropdown(code: toCurrency, onTap: onPickTo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String code;
  final VoidCallback onTap;
  const _CurrencyDropdown({required this.code, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 10, child: Icon(Icons.flag, size: 12)),
            const SizedBox(width: 6),
            Text(code, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }
}

class _RatesAndFees extends StatelessWidget {
  final String rateText;
  final String feeText;
  const _RatesAndFees({required this.rateText, required this.feeText});

  @override
  Widget build(BuildContext context) {
    Widget row(String title, String value, IconData icon) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.black54),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.black87)),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            row('Transaction rate', rateText, Icons.tag),
            row('Transaction fee', feeText, Icons.bolt),
          ],
        ),
      ),
    );
  }
}

class _SlideToConfirm extends StatefulWidget {
  final String label;
  final VoidCallback onCompleted;
  const _SlideToConfirm({required this.label, required this.onCompleted});

  @override
  State<_SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<_SlideToConfirm> {
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GestureDetector(
          onHorizontalDragUpdate: (d) {
            final width = MediaQuery.of(context).size.width - 32;
            setState(() {
              _progress = (_progress + d.delta.dx / width).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (_) {
            if (_progress > 0.85) {
              widget.onCompleted();
              setState(() => _progress = 0.0);
            } else {
              setState(() => _progress = 0.0);
            }
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, c) {
                    final knobSize = 48.0;
                    final x = (_progress * (c.maxWidth - knobSize)).clamp(
                      4.0,
                      c.maxWidth - knobSize - 4.0,
                    );
                    return Positioned(
                      left: x,
                      top: 4,
                      child: Container(
                        width: knobSize,
                        height: knobSize,
                        decoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.double_arrow,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
