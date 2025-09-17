import 'package:flutter/material.dart';

// Top Up main screen composed of smaller widgets
class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  final TextEditingController _amountCtrl = TextEditingController(
    text: '1250.00',
  );
  bool _hideBalance = false;
  double _balance =
      26135.00; // demo balance; can be wired to Firestore like WalletCard
  String _selectedBank = 'US Bank';

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _applyQuick(double v) {
    final current =
        double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
    final next = current + v;
    _amountCtrl.text = next.toStringAsFixed(2);
    setState(() {});
  }

  void _showConfirmSheet() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => TopUpConfirmSheet(
            amount: amount,
            balance: _balance,
            bankName: _selectedBank,
            onConfirm: () {
              Navigator.of(context).pop();
              _showSuccess();
            },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: primary,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Topup', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(
              _hideBalance ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance header area with subtle pattern could be added via decoration
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _BalanceHeader(balance: _balance, hidden: _hideBalance),
          ),
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
                  _SetAmountCard(
                    controller: _amountCtrl,
                    onQuickAdd: _applyQuick,
                  ),
                  const SizedBox(height: 16),
                  _BankPickerTile(
                    bankName: _selectedBank,
                    onTap: () async {
                      // Placeholder picker
                      setState(
                        () =>
                            _selectedBank =
                                _selectedBank == 'US Bank'
                                    ? 'PayPay'
                                    : 'US Bank',
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _SlideToTopUp(onCompleted: _showConfirmSheet),
        ],
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  final double balance;
  final bool hidden;
  const _BalanceHeader({required this.balance, required this.hidden});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Balance', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        Text(
          hidden ? '\$ ••••' : '\$${balance.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _SetAmountCard extends StatelessWidget {
  final TextEditingController controller;
  final void Function(double) onQuickAdd;
  const _SetAmountCard({required this.controller, required this.onQuickAdd});

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set amount',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'How much would you like to top up?',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [5, 10, 25, 50].map((e) {
                    return ActionChip(
                      label: Text('\$${e.toStringAsFixed(0)}'),
                      onPressed: () => onQuickAdd(e.toDouble()),
                      backgroundColor: primary.withOpacity(0.08),
                      labelStyle: TextStyle(
                        color: primary,
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

class _BankPickerTile extends StatelessWidget {
  final String bankName;
  final VoidCallback onTap;
  const _BankPickerTile({required this.bankName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const CircleAvatar(child: Text('US')),
        title: const Text('Bank Selected'),
        subtitle: Text(bankName),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SlideToTopUp extends StatefulWidget {
  final VoidCallback onCompleted;
  const _SlideToTopUp({required this.onCompleted});

  @override
  State<_SlideToTopUp> createState() => _SlideToTopUpState();
}

class _SlideToTopUpState extends State<_SlideToTopUp> {
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
                    'Slide to top up',
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

class TopUpConfirmSheet extends StatelessWidget {
  final double amount;
  final double balance;
  final String bankName;
  final VoidCallback onConfirm;
  const TopUpConfirmSheet({
    super.key,
    required this.amount,
    required this.balance,
    required this.bankName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
              child: const Icon(Icons.priority_high, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Amount Topup',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Top up with $bankName will not cost any fee!',
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _kv('Account Balance', '\$${balance.toStringAsFixed(2)}'),
            _kv('Top Up Amount', '\$${amount.toStringAsFixed(2)}'),
            _kv('Date', '${now.toLocal()}'.split('.').first),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SizedBox(
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
                  onPressed: onConfirm,
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: const TextStyle(color: Colors.black54)),
          ),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
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
              'Top Up Success',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Below is your top up summary',
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
                  Text('Total Top Up', style: TextStyle(color: Colors.black54)),
                  SizedBox(height: 6),
                  Text(
                    '\$1,250.00',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Top up destination',
                    style: TextStyle(color: Colors.black54),
                  ),
                  SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text('US')),
                    title: Text('US Bank'),
                    subtitle: Text('453791271  •  8:55 PM'),
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
