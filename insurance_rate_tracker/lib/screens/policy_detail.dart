import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/policy_form.dart';
import '../widgets/quote_form.dart';
import '../widgets/rate_chart.dart';
import '../widgets/rate_ladder.dart';

/// Full-screen policy page used on phones.
class PolicyDetailScreen extends StatelessWidget {
  const PolicyDetailScreen({super.key, required this.policyId});
  final String policyId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final policy = store.policyById(policyId);
    if (policy == null) {
      // The policy was deleted: leave this page.
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && route != null && route.isCurrent) Navigator.of(context).pop();
      });
      return const Scaffold();
    }
    return Scaffold(
      appBar: AppBar(title: Text(policy.name, overflow: TextOverflow.ellipsis)),
      body: SafeArea(top: false, child: PolicyDetailView(policyId: policyId)),
    );
  }
}

/// The policy's comparison, history and entries. Used on its own page on
/// phones and beside the list on tablets.
class PolicyDetailView extends StatelessWidget {
  const PolicyDetailView({super.key, required this.policyId});
  final String policyId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = store.policyById(policyId);
    if (p == null) return const SizedBox.shrink();
    final s = store.stats(p);
    return LayoutBuilder(
      builder: (context, c) => ListView(
        padding: centeredPadding(c.maxWidth),
        children: [
          _Header(policy: p, stats: s),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelHeading('Compare carriers', hint: 'Most recent rate from each company, shown ${store.basisLabel}.'),
                RateLadder(entries: _ladder(store, p, s)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelHeading('Rate history', hint: 'How each carrier’s price has moved over time.'),
                RateChart(
                  series: _series(store, p, s),
                  formatY: (v) => store.money(v, decimals: 0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Entries(policy: p, stats: s),
        ],
      ),
    );
  }

  List<LadderEntry> _ladder(AppStore store, Policy p, PolicyStats s) {
    final latest = s.latest.values.toList()..sort((a, b) => a.annual.compareTo(b.annual));
    final maxAnnual = latest.fold<double>(0, (m, q) => q.annual > m ? q.annual : m);
    final ck = carrierKey(p.carrier);
    return [
      for (var i = 0; i < latest.length; i++)
        LadderEntry(
          carrier: latest[i].carrier,
          value: store.money(store.shown(latest[i].annual)),
          fraction: maxAnnual == 0 ? 0 : latest[i].annual / maxAnnual,
          yours: ck.isNotEmpty && carrierKey(latest[i].carrier) == ck,
          lowest: i == 0 && latest.length > 1,
          stale: daysUntil(latest[i].date) < -180,
          meta: _meta(store, latest[i]),
        ),
    ];
  }

  String _meta(AppStore store, Quote q) {
    final parts = ['Quoted ${fmtDate(q.date)}'];
    final d = q.deductible;
    if (d != null) parts.add('${store.money(d, decimals: 0)} deductible');
    if (q.notes.isNotEmpty) parts.add(q.notes.length > 70 ? '${q.notes.substring(0, 70)}…' : q.notes);
    return parts.join(', ');
  }

  List<ChartSeries> _series(AppStore store, Policy p, PolicyStats s) {
    final groups = <String, List<Quote>>{};
    for (final q in s.quotes) {
      groups.putIfAbsent(carrierKey(q.carrier), () => []).add(q);
    }
    final ck = carrierKey(p.carrier);
    return [
      for (final e in groups.entries)
        ChartSeries(
          name: e.value.first.carrier,
          color: carrierColor(store.carrierIndex(e.value.first.carrier)),
          mine: ck.isNotEmpty && e.key == ck,
          points: [for (final q in e.value) ChartPoint(q.date, store.shown(q.annual))],
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.policy, required this.stats});
  final Policy policy;
  final PolicyStats stats;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rc = context.rc;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final p = policy;
    final current = stats.current;
    final best = stats.best;
    final prev = stats.previous;
    final change = stats.change;
    final renewal = p.renewal;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TypeBadge(type: p.type, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(p.carrier.isEmpty ? 'No current carrier set' : 'Insured with ${p.carrier}', style: muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (current != null)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  store.money(store.shown(current.annual)),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text('${store.perLabel} with ${p.carrier}', style: muted),
                if (change != null && prev != null)
                  StatusChip(
                    '${change > 0 ? '▲ ' : change < 0 ? '▼ ' : ''}${change.abs().toStringAsFixed(1)}% since ${fmtDate(prev.date)}',
                    kind: change > 0 ? ChipKind.bad : (change < 0 ? ChipKind.good : ChipKind.neutral),
                  ),
              ],
            )
          else
            Text(
              p.carrier.isEmpty
                  ? 'Set a current carrier and add its rate to compare against quotes.'
                  : 'No rate from ${p.carrier} yet. Add one to see how it compares.',
              style: muted,
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FactBox(label: 'Type', value: p.type.label),
              if (renewal != null)
                FactBox(
                  label: 'Renewal',
                  value: daysUntil(renewal) >= 0
                      ? '${fmtDate(renewal)} (${daysUntil(renewal)} d)'
                      : fmtDate(renewal),
                ),
              if (best != null)
                FactBox(label: 'Lowest quote', value: '${store.money(store.shown(best.annual))} ${best.carrier}'),
              if (stats.savings > 0.005)
                FactBox(
                  label: 'Potential savings',
                  value: '${store.money(store.shown(stats.savings))} ${store.perLabel}',
                  valueColor: rc.down,
                ),
            ],
          ),
          if (p.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(p.notes, style: muted),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => showQuoteForm(context, policyId: p.id),
                icon: const Icon(Icons.add),
                label: const Text('Add a rate or quote'),
              ),
              OutlinedButton.icon(
                onPressed: () => showPolicyForm(context, policy: p),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit policy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Entries extends StatelessWidget {
  const _Entries({required this.policy, required this.stats});
  final Policy policy;
  final PolicyStats stats;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final ck = carrierKey(policy.carrier);
    final qs = stats.quotes.reversed.toList();
    final n = qs.length;
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeading('All entries', hint: '$n ${n == 1 ? 'entry' : 'entries'}. Tap one to correct or delete it.'),
          for (var i = 0; i < qs.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showQuoteForm(context, policyId: policy.id, quote: qs[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      decoration: BoxDecoration(
                        color: carrierColor(store.carrierIndex(qs[i].carrier)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ck.isNotEmpty && carrierKey(qs[i].carrier) == ck ? '${qs[i].carrier} (yours)' : qs[i].carrier,
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${fmtDate(qs[i].date)}, ${store.money(qs[i].amount, decimals: 2)} ${qs[i].period.label.toLowerCase()}',
                            style: muted,
                          ),
                          if (qs[i].notes.isNotEmpty) Text(qs[i].notes, style: muted, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${store.money(store.shown(qs[i].annual))}${store.perLabel}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (qs[i].deductible != null)
                          Text('${store.money(qs[i].deductible!, decimals: 0)} deductible', style: muted),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (n == 0) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('No rates yet.', style: muted)),
        ],
      ),
    );
  }
}
