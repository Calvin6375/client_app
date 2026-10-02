import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/bottom_safe_action_bar.dart';
import 'package:pretium/widgets/currency_logo.dart';

const List<double> kMoneyQuickAmounts = [500.0, 1000.0, 2500.0, 5000.0, 10000.0];

InputDecoration moneyFieldDecoration(
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

class MoneyBalanceCard extends StatelessWidget {
  const MoneyBalanceCard({
    super.key,
    required this.currency,
    required this.balance,
    required this.loading,
    this.caption,
    this.onWalletTap,
  });

  final String currency;
  final double balance;
  final bool loading;
  final String? caption;
  final VoidCallback? onWalletTap;

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
                Expanded(
                  child: Text(
                    _formatAmount(balance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onWalletTap,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currency,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (onWalletTap != null) ...[
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onWalletTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                CurrencyLogo(code: currency, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    caption ?? 'Send from your $currency wallet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatAmount(double value) {
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

class MoneyMethodOption<T> {
  const MoneyMethodOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

class MoneyMethodDropdown<T> extends StatelessWidget {
  const MoneyMethodDropdown({
    super.key,
    required this.options,
    required this.onChanged,
    this.value,
    this.hint = 'Select method',
  });

  final T? value;
  final List<MoneyMethodOption<T>> options;
  final ValueChanged<T> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      isExpanded: true,
      hint: Text(
        hint,
        style: TextStyle(
          color: colors.textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: colors.textSecondary,
      ),
      dropdownColor: isDark ? colors.surface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: moneyFieldDecoration(context),
      selectedItemBuilder: (context) => [
        for (final option in options)
          Row(
            children: [
              Icon(option.icon, size: 20, color: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
      ],
      items: [
        for (final option in options)
          DropdownMenuItem<T>(
            value: option.value,
            child: Row(
              children: [
                Icon(option.icon, size: 20, color: primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class MoneyAmountChip extends StatelessWidget {
  const MoneyAmountChip({
    super.key,
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

class MoneyLabeledField extends StatelessWidget {
  const MoneyLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.style,
    this.inputFormatters,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          style: style ?? TextStyle(color: colors.textPrimary),
          decoration: moneyFieldDecoration(
            context,
            hint: hint,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class MoneyQrFieldButton extends StatelessWidget {
  const MoneyQrFieldButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: 'Scan QR code',
      onPressed: onPressed,
      icon: Icon(Icons.qr_code_2_rounded, color: primary),
    );
  }
}

class MoneyAmountEntry extends StatelessWidget {
  const MoneyAmountEntry({
    super.key,
    required this.controller,
    this.currency = 'KES',
    this.onChanged,
  });

  final TextEditingController controller;
  final String currency;
  final ValueChanged<String>? onChanged;

  double get _amount {
    final raw = controller.text.replaceAll(',', '').trim();
    return double.tryParse(raw) ?? 0;
  }

  static String chipLabel(double chip) {
    if (chip >= 1000) {
      return '${(chip / 1000).toStringAsFixed(chip % 1000 == 0 ? 0 : 1)}k';
    }
    return chip.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount ($currency)',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: onChanged,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          decoration: moneyFieldDecoration(context, hint: '0'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in kMoneyQuickAmounts)
              MoneyAmountChip(
                label: chipLabel(chip),
                selected: _amount == chip,
                onTap: () {
                  controller.text = chip == chip.roundToDouble()
                      ? chip.toStringAsFixed(0)
                      : chip.toStringAsFixed(2);
                  controller.selection = TextSelection.collapsed(
                    offset: controller.text.length,
                  );
                  onChanged?.call(controller.text);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class MoneyPrimaryButton extends StatelessWidget {
  const MoneyPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return BottomSafeActionBar(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: (!enabled || loading) ? null : onPressed,
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
          child: loading
              ? const ShimmerBusyIndicator(
                  width: 96,
                  height: 14,
                  onPrimary: true,
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
