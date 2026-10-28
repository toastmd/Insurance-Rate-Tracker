import 'package:flutter/material.dart';

import '../format.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CarriersScreen extends StatelessWidget {
  const CarriersScreen({super.key, required this.onBrowsePolicies});
  final VoidCallback onBrowsePolicies;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final names = store.carrierNames();
    return LayoutBuilder(builder: (context, c) {
      final pad = centeredPadding(c.maxWidth, maxContent: 720, vertical: 0);
      return CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Carriers')),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 16),
            sliver: SliverToBoxAdapter(
              child: names.isEmpty
                  ? Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No carriers yet', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('Carriers appear here once you add a policy or log a quote.',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 14),
                          FilledButton(onPressed: onBrowsePolicies, child: const Text('Go to policies')),
                        ],
                      ),
                    )
                  : Text(
                      'Every company you’ve logged, how often they come in lowest, and how their prices tend to move when you update them.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 32),
            sliver: SliverList.separated(
              itemCount: names.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _CarrierCard(name: names[i]),
            ),
          ),
        ],
      );
    });
  }
}

class _CarrierCard extends StatelessWidget {
  const _CarrierCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rc = context.rc;
    final s = store.carrierStats(name);
    final avg = s.averageChange;
    final last = s.lastDate;

    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant))),
              DefaultTextStyle.merge(style: const TextStyle(fontWeight: FontWeight.w600), child: value),
            ],
          ),
        );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: carrierColor(store.carrierIndex(name)),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            s.insuring.isEmpty
                ? 'Not currently insuring you'
                : 'Your carrier for ${s.insuring.map((p) => p.name).join(', ')}',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          row('Rates logged', Text('${s.quoteCount}')),
          row('Policies quoted', Text('${s.policiesQuoted}')),
          row('Lowest price on', Text('${s.lowestOn} ${s.lowestOn == 1 ? 'policy' : 'policies'}')),
          row(
            'Average change per update',
            avg == null
                ? Text('Not enough data', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400))
                : Text('${avg > 0 ? '+' : ''}${avg.toStringAsFixed(1)}%',
                    style: TextStyle(color: avg > 0 ? rc.up : rc.down)),
          ),
          if (last != null) row('Last rate', Text(fmtDate(last))),
        ],
      ),
    );
  }
}
