import 'package:flutter/material.dart';

class AddRecipientScreen extends StatefulWidget {
  const AddRecipientScreen({super.key});

  @override
  State<AddRecipientScreen> createState() => _AddRecipientScreenState();
}

class _AddRecipientScreenState extends State<AddRecipientScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Recipients'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(label: 'Account Number'),
              const SizedBox(height: 24),
              _buildTextField(label: 'Full Name'),
              const SizedBox(height: 24),
              _buildDropdownField(
                label: 'Country',
                items: ['Nigeria', 'Kenya', 'Ghana', 'USA'],
              ),
              const SizedBox(height: 24),
              _buildDropdownField(
                label: 'Select Bank',
                items: ['GTBank', 'Kuda Bank', 'Opay', 'Access Bank'],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  // TODO: Save changes logic
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.grey.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({required String label, required List<String> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (value) {},
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ],
    );
  }
}
