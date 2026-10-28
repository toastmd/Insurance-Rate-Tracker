import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

class LadderEntry {
  const LadderEntry({
    required this.carrier,
    required this.value,
    required this.fraction,
    required this.meta,
    this.yours = false,
    this.lowest = false,
    this.stale = false,
  });
  final String carrier;
  final String value;
  final double fraction;
  final String meta;
  final bool yours, lowest, stale;
}

/// Horizontal bars comparing each carrier's latest price, cheapest first.
class RateLadder extends StatelessWidget {
  const RateLadder({super.key, required this.entries});
  final List<LadderEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rc = context.rc;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (entries.isEmpty) {
      return Text('No rates yet.', style: TextStyle(color: scheme.onSurfaceVariant));
    }
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(e.carrier, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          if (e.yours) const StatusChip('Yours', kind: ChipKind.brand),
                          if (e.lowest) const StatusChip('Lowest', kind: ChipKind.good),
                          if (e.stale) const StatusChip('Over 6 months old'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      e.value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    height: 14,
                    color: scheme.surfaceContainerLow,
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: max(0.04, e.fraction)),
                      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => FractionallySizedBox(
                        widthFactor: v,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: e.yours ? scheme.primary : (e.lowest ? rc.down : rc.bar),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(e.meta, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}
