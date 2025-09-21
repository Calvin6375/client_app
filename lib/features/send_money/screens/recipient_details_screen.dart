import 'package:flutter/material.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/models/transaction_details_model.dart';

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

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController(text: widget.initialDetails.recipientFullName);
    _phoneCtrl = TextEditingController(text: widget.initialDetails.recipientPhoneNumber);
    _bankNameCtrl = TextEditingController(text: widget.initialDetails.recipientBankName);
    _accountNumberCtrl = TextEditingController(text: widget.initialDetails.recipientAccountNumber);

    _fullNameCtrl.addListener(_onChanged);
    _phoneCtrl.addListener(_onChanged);
    _bankNameCtrl.addListener(_onChanged);
    _accountNumberCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    widget.onUpdate(
      TransactionDetails(
        recipientFullName: _fullNameCtrl.text,
        recipientPhoneNumber: _phoneCtrl.text,
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recipient Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildTextField(label: 'Full Name', controller: _fullNameCtrl),
                  const SizedBox(height: 24),
                  _buildTextField(label: 'Phone Number', controller: _phoneCtrl),
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
              onPressed: widget.onNext,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
