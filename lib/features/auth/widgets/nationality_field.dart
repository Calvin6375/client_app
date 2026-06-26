import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/auth/data/nationalities.dart';

/// Nationality picker styled like other registration fields.
class NationalityField extends FormField<NationalityOption> {
  NationalityField({
    super.key,
    required Color primaryColor,
    Color? labelColor,
    NationalityOption? initialValue,
    super.onSaved,
    super.validator,
    required ValueChanged<NationalityOption> onChanged,
  }) : super(
          initialValue: initialValue,
          builder: (state) {
            final colors = AppColors.getThemeColors(
              state.context,
            );
            final selected = state.value;
            final displayText = selected?.name ?? 'Select nationality';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _showPicker(
                    state.context,
                    primaryColor: primaryColor,
                    selected: selected,
                    onSelected: (option) {
                      state.didChange(option);
                      onChanged(option);
                    },
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.public_outlined,
                        color: colors.iconPrimary,
                      ),
                      suffixIcon: Icon(
                        Icons.arrow_drop_down,
                        color: primaryColor,
                      ),
                      labelText: 'Nationality',
                      hintText: 'Select nationality',
                      hintStyle: TextStyle(color: colors.inputPlaceholder),
                      labelStyle: TextStyle(
                        color: labelColor ?? primaryColor,
                      ),
                      floatingLabelStyle: TextStyle(
                        color: labelColor ?? primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: colors.inputBorderFocused,
                          width: 2,
                        ),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.inputBorder),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.error),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.error, width: 2),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      errorText: state.errorText,
                    ),
                    child: Row(
                      children: [
                        if (selected != null) ...[
                          Text(
                            selected.flag,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            displayText,
                            style: TextStyle(
                              color: selected == null
                                  ? colors.inputPlaceholder
                                  : colors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );

  static Future<void> _showPicker(
    BuildContext context, {
    required Color primaryColor,
    required NationalityOption? selected,
    required ValueChanged<NationalityOption> onSelected,
  }) async {
    final searchController = TextEditingController();
    var filtered = List<NationalityOption>.from(kNationalities);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void applyFilter(String query) {
              final q = query.trim().toLowerCase();
              setSheetState(() {
                filtered = q.isEmpty
                    ? List<NationalityOption>.from(kNationalities)
                    : kNationalities
                        .where(
                          (n) =>
                              n.name.toLowerCase().contains(q) ||
                              n.isoCode.toLowerCase().contains(q),
                        )
                        .toList();
              });
            }

            final colors = AppColors.getThemeColors(context);
            final maxHeight = MediaQuery.of(context).size.height * 0.75;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: maxHeight,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select nationality',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        onChanged: applyFilter,
                        decoration: InputDecoration(
                          hintText: 'Search by country',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No countries found',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                final isSelected =
                                    option.isoCode == selected?.isoCode;
                                return ListTile(
                                  leading: Text(
                                    option.flag,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  title: Text(option.name),
                                  trailing: isSelected
                                      ? Icon(Icons.check, color: primaryColor)
                                      : null,
                                  selected: isSelected,
                                  onTap: () {
                                    onSelected(option);
                                    Navigator.pop(sheetContext);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }
}
