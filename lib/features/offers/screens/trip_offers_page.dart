import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_ai/data/safari_ai_guide.dart';

/// Mock trip packages for Financial Services → Offers.
class TripOffersPage extends StatefulWidget {
  const TripOffersPage({super.key});

  @override
  State<TripOffersPage> createState() => _TripOffersPageState();
}

class _TripOffersPageState extends State<TripOffersPage> {
  String? _country;
  String? _season;
  String? _mood;
  String? _budget;

  List<SafariDestination> get _filtered {
    return SafariAiSession.destinations.where(_matches).toList(growable: false);
  }

  bool get _hasFilters =>
      _country != null || _season != null || _mood != null || _budget != null;

  bool _matches(SafariDestination trip) {
    if (_country != null && trip.country != _country) return false;
    if (_season != null && !trip.seasons.contains(_season)) return false;
    if (_mood != null && !trip.moods.contains(_mood)) return false;
    if (_budget != null && trip.budgetBand != _budget) return false;
    return true;
  }

  void _clearFilters() {
    setState(() {
      _country = null;
      _season = null;
      _mood = null;
      _budget = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final results = _filtered;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor:
            isDark ? Colors.transparent : primary.withValues(alpha: 0.08),
        elevation: 0,
        title: Text(
          'Offers',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          if (_hasFilters)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Trip packages you can pay for with SafariTap.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          _FilterRow(
            label: 'Country',
            options: const ['Kenya', 'Tanzania', 'Rwanda'],
            selected: _country,
            onSelected: (value) => setState(() => _country = value),
          ),
          _FilterRow(
            label: 'Season',
            options: const [
              'Dry (Jun–Oct)',
              'Migration',
              'Hot months (Dec–Mar)',
              'Year-round',
            ],
            selected: _season,
            onSelected: (value) => setState(() => _season = value),
          ),
          _FilterRow(
            label: 'Mood',
            options: const [
              'Safari',
              'Beach',
              'Culture',
              'Weekend',
              'Budget',
              'Remote',
            ],
            selected: _mood,
            onSelected: (value) => setState(() => _mood = value),
          ),
          _FilterRow(
            label: 'Budget',
            options: const ['Under 20k', '20–40k', '40k and up'],
            selected: _budget,
            onSelected: (value) => setState(() => _budget = value),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              results.isEmpty
                  ? 'No packages match these filters'
                  : '${results.length} package${results.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.travel_explore_rounded,
                            size: 40,
                            color: colors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Try another country, season, or budget.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('Show all offers'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final trip = results[index];
                      return _TripOfferCard(
                        trip: trip,
                        onTap: () => _openTrip(context, trip),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openTrip(BuildContext context, SafariDestination trip) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
          ),
          decoration: BoxDecoration(
            color: isDark ? colors.surface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        trip.name,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trip.region,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Tag(label: trip.vibe, primary: primary),
                          _Tag(label: trip.fromKes, primary: primary),
                          _Tag(label: trip.country, primary: primary),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        trip.hook,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        trip.why,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Best season',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trip.season,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Itinerary',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final line in trip.itinerary)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            line,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Booking is a preview. Packages are mock offers for now.',
                              ),
                            ),
                          );
                        },
                        child: const Text('Book with SafariTap'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              label,
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = options[index];
                final isOn = selected == option;
                return Material(
                  color: isOn
                      ? primary
                      : (isDark ? colors.surface : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => onSelected(isOn ? null : option),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          color: isOn ? Colors.white : colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.primary});

  final String label;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TripOfferCard extends StatelessWidget {
  const _TripOfferCard({required this.trip, required this.onTap});

  final SafariDestination trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: isDark ? colors.surface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? colors.border.withValues(alpha: 0.5)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                trip.region,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                trip.hook,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.fromKes,
                      style: TextStyle(
                        color: primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    trip.vibe,
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _TripOfferFilters on SafariDestination {
  String get country {
    final head = region.split('·').first.trim();
    if (head.isEmpty) return 'Kenya';
    return head;
  }

  int get priceKes {
    final match = RegExp(r'KES\s*([\d,]+)').firstMatch(fromKes);
    if (match == null) return 0;
    return int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
  }

  String get budgetBand {
    final price = priceKes;
    if (price > 0 && price < 20000) return 'Under 20k';
    if (price <= 40000) return '20–40k';
    return '40k and up';
  }

  Set<String> get seasons {
    final text = season.toLowerCase();
    final tags = <String>{};
    if (text.contains('year-round')) tags.add('Year-round');
    if (id == 'mara') tags.add('Migration');
    if (text.contains('jun') || text.contains('jul') || text.contains('sep')) {
      tags.add('Dry (Jun–Oct)');
    }
    if (text.contains('dec') ||
        text.contains('jan') ||
        text.contains('feb') ||
        text.contains('mar')) {
      tags.add('Hot months (Dec–Mar)');
    }
    if (id == 'naivasha') tags.add('Year-round');
    return tags;
  }

  Set<String> get moods {
    final text = '$vibe $hook $why'.toLowerCase();
    final tags = <String>{};
    if (text.contains('beach') || text.contains('sand') || text.contains('dhow')) {
      tags.add('Beach');
    }
    if (text.contains('culture') ||
        text.contains('slow') ||
        text.contains('town')) {
      tags.add('Culture');
    }
    if (text.contains('weekend')) tags.add('Weekend');
    if (text.contains('budget') || text.contains('value') || priceKes < 20000) {
      tags.add('Budget');
    }
    if (text.contains('remote') || text.contains('vast') || text.contains('wild')) {
      tags.add('Remote');
    }
    if (text.contains('big five') ||
        text.contains('elephant') ||
        text.contains('lion') ||
        text.contains('gorilla') ||
        text.contains('game')) {
      tags.add('Safari');
    }
    return tags;
  }
}
