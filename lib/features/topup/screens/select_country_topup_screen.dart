import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/services/topup_countries_api_service.dart';

/// First step when the user taps **Top Up** on the wallet: pick a deposit country, then continue to [TopUpPage].
///
/// Countries are loaded from `GET …/api/countries` (see [TopupCountriesApiService]).
class SelectCountryTopUpScreen extends StatefulWidget {
  const SelectCountryTopUpScreen({super.key});

  @override
  State<SelectCountryTopUpScreen> createState() =>
      _SelectCountryTopUpScreenState();
}

class _SelectCountryTopUpScreenState extends State<SelectCountryTopUpScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TopupCountriesApiService _countriesApi = TopupCountriesApiService();

  bool _loading = true;
  String? _error;
  List<TopupDepositCountry> _countries = const [];

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _countriesApi.fetchEnabledCountries();
      if (!mounted) return;
      setState(() {
        _countries = list;
        _loading = false;
        if (list.isEmpty) {
          _error = 'No countries are available right now.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _countries = const [];
        _error = e is TopupCountriesApiException
            ? e.message
            : 'Could not load countries. Check your connection and try again.';
      });
    }
  }

  List<TopupDepositCountry> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _countries;
    return _countries.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.currencyName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onAccent = Theme.of(context).brightness == Brightness.dark
        ? colors.onPrimary
        : Colors.white;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Select country',
          style:
              TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Where are you topping up from?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the country for your local fiat payment. You can pick a payment method on the next screens.',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    enabled:
                        !_loading && _error == null && _countries.isNotEmpty,
                    style: TextStyle(color: colors.textPrimary),
                    cursorColor: primary,
                    decoration: InputDecoration(
                      hintText: 'Search by country or currency',
                      hintStyle: TextStyle(color: colors.inputPlaceholder),
                      prefixIcon:
                          Icon(Icons.search, color: colors.iconSecondary),
                      filled: true,
                      fillColor: colors.inputBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: colors.inputBorderFocused, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(colors, primary, isDark, onAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      AppThemeColors colors, Color primary, bool isDark, Color onAccent) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: primary),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public_off_rounded,
                size: 48, color: colors.textTertiary),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colors.textSecondary, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loadCountries,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: onAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Retry',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No countries match your search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 15),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final c = _filtered[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(c),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Row(
                  children: [
                    Text(c.flagEmoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${c.currencyName} (${c.code})',
                            style: TextStyle(
                                fontSize: 13, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color:
                          isDark ? colors.textTertiary : colors.iconSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
