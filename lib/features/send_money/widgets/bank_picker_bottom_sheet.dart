import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_bank.dart';

/// Bank list sheet for Send Money — same height/layout as [CurrencyPickerBottomSheet].
class BankPickerBottomSheet extends StatefulWidget {
  const BankPickerBottomSheet({
    super.key,
    required this.banks,
    required this.onSelected,
    this.selectedCode,
  });

  final List<SafariTapBank> banks;
  final String? selectedCode;
  final ValueChanged<SafariTapBank> onSelected;

  /// Shared with the wallet picker so both sheets match visually.
  static double sheetHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height * 0.55;

  @override
  State<BankPickerBottomSheet> createState() => _BankPickerBottomSheetState();
}

class _BankPickerBottomSheetState extends State<BankPickerBottomSheet> {
  final _searchCtrl = TextEditingController();
  late List<SafariTapBank> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List<SafariTapBank>.from(widget.banks);
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List<SafariTapBank>.from(widget.banks);
        return;
      }
      _filtered = widget.banks.where((bank) {
        return bank.name.toLowerCase().contains(q) ||
            bank.code.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final sheetColor =
        isDark ? colors.surface : Colors.white.withValues(alpha: 0.9);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Material(
          color: sheetColor,
          elevation: isDark ? 0 : 2,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            side: isDark
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: BankPickerBottomSheet.sheetHeight(context),
            child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.textTertiary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_rounded, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      'Select bank',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search banks',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    prefixIcon: Icon(Icons.search, color: colors.textSecondary),
                    filled: true,
                    fillColor: isDark
                        ? colors.background
                        : const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No banks found',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark
                              ? colors.surfaceVariant
                              : const Color(0xFFE5E7EB),
                        ),
                        itemBuilder: (context, i) {
                          final bank = _filtered[i];
                          final isSelected = bank.code == widget.selectedCode;
                          return ListTile(
                            title: Text(
                              bank.name,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check, color: primary)
                                : null,
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onSelected(bank);
                            },
                          );
                        },
                      ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
