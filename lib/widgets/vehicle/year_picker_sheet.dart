import 'package:flutter/material.dart';
import '../../core/constants/spacing.dart';

/// Year (年式) picker bottom sheet.
///
/// Model years are a finite, enumerable range, so unlike body color there is
/// no free-text fallback: picking from a list is both faster and typo-proof.
/// Each entry shows the Japanese era (和暦) alongside the western year because
/// 車検証 states the first registration date in 和暦 — users often only know
/// "平成30年式".

/// Oldest selectable model year. Classic cars still on Japanese roads rarely
/// predate this (昭和30年).
const int kMinVehicleYear = 1955;

/// Formats [year] as "2023年（令和5年）".
///
/// Era conversion: 令和 = year - 2018 (2019〜), 平成 = year - 1988
/// (1989〜2018), 昭和 = year - 1925 (1926〜1988). Years outside those eras
/// are shown without a 和暦 suffix.
String formatYearWithWareki(int year) {
  final String? wareki;
  if (year >= 2019) {
    wareki = '令和${year - 2018}年';
  } else if (year >= 1989) {
    wareki = '平成${year - 1988}年';
  } else if (year >= 1926) {
    wareki = '昭和${year - 1925}年';
  } else {
    wareki = null;
  }
  return wareki == null ? '$year年' : '$year年（$wareki）';
}

/// Shows a bottom sheet listing 今年+1 〜 [kMinVehicleYear] (newest first)
/// and resolves with the tapped year, or null when dismissed.
///
/// [selected] marks the currently chosen year with a checkmark.
Future<int?> showYearPickerSheet(BuildContext context, {int? selected}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _YearPickerSheet(selected: selected),
  );
}

class _YearPickerSheet extends StatelessWidget {
  final int? selected;

  const _YearPickerSheet({this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // +1 covers next-year models sold ahead of the calendar year.
    final maxYear = DateTime.now().year + 1;
    final years = [for (var y = maxYear; y >= kMinVehicleYear; y--) y];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AppSpacing.verticalMd,
                  Text(
                    '年式を選択',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = year == selected;

                  return ListTile(
                    title: Text(formatYearWithWareki(year)),
                    selected: isSelected,
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => Navigator.pop(context, year),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
