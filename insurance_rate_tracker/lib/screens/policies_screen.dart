import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/policy_form.dart';
import 'policy_detail.dart';

class PoliciesScreen extends StatelessWidget {
  const PoliciesScreen({super.key, required this.wide, required this.selectedId, required this.onSelect});
  final bool wide;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final id = selectedId;
    final selected = id != null && store.policyById(id) != null ? id : null;
    final list = _PolicyList(selectedId: wide ? selected : null, onSelect: onSelect);
    if (!wide || store.policies.isEmpty) return list;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 400, child: list),
        VerticalDivider(width: 1, color: scheme.outlineVariant),
        Expanded(
          child: selected == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Select a policy to compare carriers and see its rate history.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : PolicyDetailView(key: ValueKey(selected), policyId: selected),
        ),
      ],
    );
  }
}

class _PolicyList extends StatelessWidget {
  const _PolicyList({required this.selectedId, required this.onSelect});
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final policies = store.sortedPolicies;
    return LayoutBuilder(builder: (context, c) {
      final pad = centeredPadding(c.maxWidth, maxContent: 640, vertical: 0);
      return CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Rates'),
            actions: [
              IconButton(
                tooltip: 'Add a policy',
                icon: const Icon(Icons.add),
                onPressed: () => showPolicyForm(context, onCreated: onSelect),
              ),
            ],
          ),
          if (policies.isEmpty)
            SliverPadding(
              padding: pad,
              sliver: SliverToBoxAdapter(child: _EmptyState(onSelect: onSelect)),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 18),
              sliver: const SliverToBoxAdapter(child: _Summary()),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad.left),
              sliver: SliverList.separated(
                itemCount: policies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => PolicyTile(
                  policy: policies[i],
                  selected: policies[i].id == selectedId,
                  onTap: () => onSelect(policies[i].id),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad.left, 16, pad.right, 32),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => showPolicyForm(context, onCreated: onSelect),
                    icon: const Icon(Icons.add),
                    label: const Text('Add a policy'),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    var total = 0.0, savings = 0.0, counted = 0;
    for (final p in store.policies) {
      final s = store.stats(p);
      final current = s.current;
      if (current != null) {
        total += current.annual;
        counted++;
      }
      savings += s.savings;
    }
    final n = store.policies.length;
    final muted = theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: store.money(store.shown(total)),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -1.5,
                color: scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            TextSpan(text: '  ${store.basisLabel}', style: muted),
          ]),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(style: muted, children: [
            TextSpan(
              text: counted < n
                  ? '$counted of $n policies have a current rate entered.'
                  : 'Across $n ${n == 1 ? 'policy' : 'policies'}.',
            ),
            if (savings > 0.005) ...[
              const TextSpan(text: ' The lowest quotes on file would save you '),
              TextSpan(
                text: store.money(store.shown(savings)),
                style: TextStyle(color: context.rc.down, fontWeight: FontWeight.w700),
              ),
              TextSpan(text: ' ${store.perWord}.'),
            ],
          ]),
        ),
      ],
    );
  }
}

class PolicyTile extends StatelessWidget {
  const PolicyTile({super.key, required this.policy, required this.selected, required this.onTap});
  final Policy policy;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = store.stats(policy);
    final current = s.current;
    final change = s.change;
    final renewal = policy.renewal;

    final lines = <String>[policy.carrier.isEmpty ? 'No current carrier' : policy.carrier];
    if (renewal != null) {
      final d = daysUntil(renewal);
      lines.add(d < 0 ? 'Renewal date passed' : d == 0 ? 'Renews today' : 'Renews in $d day${d == 1 ? '' : 's'}');
    }

    Widget? chip;
    if (s.savings > 0.005) {
      chip = StatusChip('Save ${store.money(store.shown(s.savings))}', kind: ChipKind.good);
    } else if (change != null && change.abs() >= 0.5) {
      chip = StatusChip('${change > 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(1)}%',
          kind: change > 0 ? ChipKind.bad : ChipKind.good);
    } else if (renewal != null && daysUntil(renewal) >= 0 && daysUntil(renewal) <= 30) {
      chip = const StatusChip('Shop now', kind: ChipKind.bad);
    }

    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              TypeBadge(type: policy.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(policy.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    for (final l in lines) Text(l, style: muted),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (current != null) ...[
                    Text(
                      store.money(store.shown(current.annual)),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(store.perLabel, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ] else
                    Text('No rate yet', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  if (chip != null) ...[const SizedBox(height: 4), chip],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSelect});
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Track what you pay, and what you could pay',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Add a policy such as your car or home, enter what your current carrier charges, then log quotes from other companies as you collect them. You’ll see who’s cheapest and how each rate changes at renewal.',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => showPolicyForm(context, onCreated: onSelect),
                child: const Text('Add a policy'),
              ),
              OutlinedButton(
                onPressed: () {
                  final id = StoreScope.read(context).loadSample();
                  onSelect(id);
                },
                child: const Text('Try with sample data'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
