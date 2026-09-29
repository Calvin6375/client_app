import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/topup/models/create_payment_result.dart';

Future<void> _copyValue(BuildContext context, String label, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label copied')),
  );
}

class UsdFundingInstructionsScreen extends StatelessWidget {
  const UsdFundingInstructionsScreen({
    super.key,
    required this.result,
  });

  final CreatePaymentResult result;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final amount = result.amount;
    final currency = result.currency ?? 'USD';
    final amountLabel = amount == null
        ? currency
        : '${amount.toStringAsFixed(2)} $currency';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'USD funding',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'Send USD using one of the payment methods below. Your TruePay balance will update after the payment is received and confirmed.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _SummaryCard(
            fundingOrderId: result.fundingOrderId,
            amountLabel: amountLabel,
            status: result.status ?? 'pending',
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < result.instructions.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _FundingMethodCard(
              index: i,
              instruction: result.instructions[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.fundingOrderId,
    required this.amountLabel,
    required this.status,
  });

  final String? fundingOrderId;
  final String amountLabel;
  final String status;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fundingOrderId != null) ...[
            _MetaRow(label: 'Funding order', value: fundingOrderId!),
            const SizedBox(height: 10),
          ],
          _MetaRow(label: 'Amount', value: amountLabel),
          const SizedBox(height: 10),
          _MetaRow(label: 'Status', value: status),
        ],
      ),
    );
  }
}

class _FundingMethodCard extends StatelessWidget {
  const _FundingMethodCard({
    required this.index,
    required this.instruction,
  });

  final int index;
  final FundingPaymentInstruction instruction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final account = instruction.account;
    final title = _methodTitle(account, index);

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (instruction.instructionsNotes != null) ...[
            _NotesBanner(text: instruction.instructionsNotes!),
            const SizedBox(height: 12),
          ],
          _OptionalField(
            label: 'Bank name',
            value: account.bankName,
          ),
          _OptionalField(
            label: 'Account holder',
            value: account.accountHolderName,
          ),
          _OptionalField(
            label: 'Account number',
            value: account.accountNumber,
          ),
          _OptionalField(
            label: 'Routing number',
            value: account.routingNumber,
          ),
          _OptionalField(
            label: 'SWIFT code',
            value: account.swiftCode,
          ),
          _OptionalField(
            label: 'Bank address',
            value: account.bankAddress,
          ),
          _OptionalField(
            label: 'Account type',
            value: account.accountType,
          ),
          _OptionalField(
            label: 'Country',
            value: account.country,
          ),
          _OptionalField(
            label: 'Payment rails',
            value: account.paymentRails.isEmpty
                ? null
                : account.paymentRails.join(' · '),
          ),
          _OptionalField(
            label: 'Reference',
            value: account.reference,
            emphasize: true,
          ),
        ],
      ),
    );
  }

  String _methodTitle(FundingAccountInfo account, int index) {
    if (account.accountType != null) {
      return account.accountType!.replaceAll('_', ' ');
    }
    if (account.bankName != null) return account.bankName!;
    return 'Funding method ${index + 1}';
  }
}

class _NotesBanner extends StatelessWidget {
  const _NotesBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 13,
          height: 1.35,
        ),
      ),
    );
  }
}

class _OptionalField extends StatelessWidget {
  const _OptionalField({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String? value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value!,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy $label',
            visualDensity: VisualDensity.compact,
            onPressed: () => _copyValue(context, label, value!),
            icon: Icon(
              Icons.copy_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy $label',
          visualDensity: VisualDensity.compact,
          onPressed: () => _copyValue(context, label, value),
          icon: Icon(
            Icons.copy_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}
