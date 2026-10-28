import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';
import 'models.dart';

/// Derived numbers for one policy.
class PolicyStats {
  const PolicyStats({
    required this.quotes,
    required this.latest,
    this.current,
    this.best,
    this.previous,
    this.change,
    this.savings = 0,
  });

  /// All quotes for the policy, oldest first.
  final List<Quote> quotes;

  /// Most recent quote per carrier, keyed by [carrierKey].
  final Map<String, Quote> latest;

  /// Latest quote from the policy's current carrier.
  final Quote? current;

  /// Cheapest of the latest quotes.
  final Quote? best;

  /// The current carrier's quote before [current].
  final Quote? previous;

  /// Percent change from [previous] to [current].
  final double? change;

  /// Annual amount saved by switching to [best]. Zero if already cheapest.
  final double savings;
}

class CarrierStats {
  const CarrierStats({
    required this.name,
    required this.quoteCount,
    required this.policiesQuoted,
    required this.lowestOn,
    required this.averageChange,
    required this.lastDate,
    required this.insuring,
  });
  final String name;
  final int quoteCount;
  final int policiesQuoted;
  final int lowestOn;
  final double? averageChange;
  final DateTime? lastDate;
  final List<Policy> insuring;
}

/// Holds all app data, persists it on the device and computes comparisons.
/// The JSON format matches the web version's backup files, so backups move
/// freely between the two.
class AppStore extends ChangeNotifier {
  static const storageKey = 'insurance-rate-tracker-v1';

  final List<Policy> policies = [];
  final List<Quote> quotes = [];
  Basis basis = Basis.month;
  String currency = 'USD';
  int updatedAt = 0;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(storageKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw);
      if (j is Map) applyJson(Map<String, dynamic>.from(j));
    } catch (_) {
      // Corrupt data: start empty rather than crash.
    }
  }

  void applyJson(Map<String, dynamic> j) {
    final ps = <Policy>[];
    final seen = <String>{};
    final rawP = j['policies'];
    if (rawP is List) {
      for (final m in rawP) {
        if (m is! Map) continue;
        final p = Policy.fromJson(Map<String, dynamic>.from(m));
        if (p != null && seen.add(p.id)) ps.add(p);
      }
    }
    final qs = <Quote>[];
    final rawQ = j['quotes'];
    if (rawQ is List) {
      for (final m in rawQ) {
        if (m is! Map) continue;
        final q = Quote.fromJson(Map<String, dynamic>.from(m));
        if (q != null && seen.contains(q.policyId)) qs.add(q);
      }
    }
    policies
      ..clear()
      ..addAll(ps);
    quotes
      ..clear()
      ..addAll(qs);
    final pr = j['prefs'];
    if (pr is Map) {
      basis = pr['basis'] == 'year' ? Basis.year : Basis.month;
      final c = pr['currency'];
      if (c is String && RegExp(r'^[A-Z]{3}$').hasMatch(c)) currency = c;
    }
    final u = j['updatedAt'];
    updatedAt = u is num ? u.toInt() : 0;
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'policies': policies.map((p) => p.toJson()).toList(),
        'quotes': quotes.map((q) => q.toJson()).toList(),
        'prefs': {'basis': basis.name, 'currency': currency},
        'updatedAt': updatedAt,
      };

  void _commit() {
    updatedAt = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _prefs?.setString(storageKey, jsonEncode(toJson()));
  }

  /// Call after mutating a [Policy] or [Quote] in place.
  void save() => _commit();

  // ---------- policies ----------

  Policy? policyById(String id) {
    for (final p in policies) {
      if (p.id == id) return p;
    }
    return null;
  }

  Policy addPolicy({
    required String name,
    required PolicyType type,
    String carrier = '',
    DateTime? renewal,
    String notes = '',
    double? premium,
    BillingPeriod period = BillingPeriod.month,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = Policy(
      id: newId(),
      name: name,
      type: type,
      carrier: carrier,
      renewal: renewal,
      notes: notes,
      created: now,
    );
    policies.add(p);
    if (premium != null && carrier.isNotEmpty) {
      quotes.add(Quote(
        id: newId(),
        policyId: p.id,
        carrier: carrier,
        amount: premium,
        period: period,
        date: today(),
        created: now,
      ));
    }
    _commit();
    return p;
  }

  void deletePolicy(String id) {
    policies.removeWhere((p) => p.id == id);
    quotes.removeWhere((q) => q.policyId == id);
    _commit();
  }

  /// Policies ordered by soonest upcoming renewal, then name.
  List<Policy> get sortedPolicies {
    int rank(Policy p) {
      final r = p.renewal;
      if (r == null) return 1 << 30;
      final d = daysUntil(r);
      return d < 0 ? (1 << 29) : d;
    }

    return [...policies]..sort((a, b) {
        final c = rank(a).compareTo(rank(b));
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  // ---------- quotes ----------

  void addQuote(Quote q, {bool makeCurrent = false}) {
    quotes.add(q);
    if (makeCurrent) policyById(q.policyId)?.carrier = q.carrier;
    _commit();
  }

  void updateQuote(Quote q, {bool makeCurrent = false}) {
    if (makeCurrent) policyById(q.policyId)?.carrier = q.carrier;
    _commit();
  }

  void deleteQuote(String id) {
    quotes.removeWhere((q) => q.id == id);
    _commit();
  }

  Quote? quoteById(String id) {
    for (final q in quotes) {
      if (q.id == id) return q;
    }
    return null;
  }

  static int _byDate(Quote a, Quote b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.created.compareTo(b.created);
  }

  List<Quote> quotesFor(String policyId) =>
      quotes.where((q) => q.policyId == policyId).toList()..sort(_byDate);

  PolicyStats stats(Policy p) {
    final qs = quotesFor(p.id);
    final latest = <String, Quote>{};
    for (final q in qs) {
      latest[carrierKey(q.carrier)] = q;
    }
    final ck = carrierKey(p.carrier);
    final current = ck.isEmpty ? null : latest[ck];
    Quote? best;
    for (final q in latest.values) {
      if (best == null || q.annual < best.annual) best = q;
    }
    final mine = ck.isEmpty
        ? <Quote>[]
        : qs.where((q) => carrierKey(q.carrier) == ck).toList();
    final prev = mine.length > 1 ? mine[mine.length - 2] : null;
    double? change;
    if (current != null && prev != null && prev.annual > 0) {
      change = (current.annual - prev.annual) / prev.annual * 100;
    }
    var savings = 0.0;
    if (current != null && best != null && carrierKey(best.carrier) != ck) {
      savings = max(0.0, current.annual - best.annual);
    }
    return PolicyStats(
      quotes: qs,
      latest: latest,
      current: current,
      best: best,
      previous: prev,
      change: change,
      savings: savings,
    );
  }

  // ---------- carriers ----------

  /// Display names of every carrier, sorted, one per [carrierKey].
  List<String> carrierNames() {
    final m = <String, String>{};
    for (final q in quotes) {
      final k = carrierKey(q.carrier);
      if (k.isNotEmpty) m.putIfAbsent(k, () => q.carrier.trim());
    }
    for (final p in policies) {
      final k = carrierKey(p.carrier);
      if (k.isNotEmpty) m.putIfAbsent(k, () => p.carrier.trim());
    }
    return m.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Stable index for coloring a carrier consistently across screens.
  int carrierIndex(String name) {
    final keys = carrierNames().map(carrierKey).toList();
    final i = keys.indexOf(carrierKey(name));
    return i < 0 ? 0 : i;
  }

  CarrierStats carrierStats(String name) {
    final k = carrierKey(name);
    final qs = quotes.where((q) => carrierKey(q.carrier) == k).toList()..sort(_byDate);
    final pids = qs.map((q) => q.policyId).toSet();
    var lowest = 0;
    final changes = <double>[];
    for (final pid in pids) {
      final p = policyById(pid);
      if (p == null) continue;
      final s = stats(p);
      final best = s.best;
      if (best != null && carrierKey(best.carrier) == k && s.latest.length > 1) lowest++;
      final mine = qs.where((q) => q.policyId == pid).toList();
      for (var i = 1; i < mine.length; i++) {
        final a = mine[i - 1].annual;
        if (a > 0) changes.add((mine[i].annual - a) / a * 100);
      }
    }
    return CarrierStats(
      name: name,
      quoteCount: qs.length,
      policiesQuoted: pids.length,
      lowestOn: lowest,
      averageChange:
          changes.isEmpty ? null : changes.reduce((a, b) => a + b) / changes.length,
      lastDate: qs.isEmpty ? null : qs.last.date,
      insuring: policies.where((p) => carrierKey(p.carrier) == k).toList(),
    );
  }

  // ---------- display ----------

  double shown(double annual) => basis == Basis.month ? annual / 12 : annual;
  String money(double v, {int? decimals}) =>
      formatMoney(v, currency, decimals ?? (basis == Basis.month ? 2 : 0));
  String get perLabel => basis == Basis.month ? '/mo' : '/yr';
  String get perWord => basis == Basis.month ? 'a month' : 'a year';
  String get basisLabel => basis == Basis.month ? 'per month' : 'per year';

  void setBasis(Basis b) {
    basis = b;
    _commit();
  }

  void setCurrency(String c) {
    currency = c;
    _commit();
  }

  // ---------- backup ----------

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  String exportCsv() {
    String cell(Object? v) {
      final s = v?.toString() ?? '';
      return RegExp(r'[",\n\r]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final rows = <List<Object?>>[
      ['Policy', 'Type', 'Carrier', 'Current carrier', 'Date', 'Premium', 'Billed',
        'Annual cost', 'Monthly cost', 'Deductible', 'Notes'],
    ];
    for (final p in policies) {
      for (final q in quotesFor(p.id)) {
        rows.add([
          p.name,
          p.type.label,
          q.carrier,
          carrierKey(q.carrier) == carrierKey(p.carrier) ? 'Yes' : 'No',
          isoDate(q.date),
          q.amount.toStringAsFixed(2),
          q.period.label,
          q.annual.toStringAsFixed(2),
          (q.annual / 12).toStringAsFixed(2),
          q.deductible?.toStringAsFixed(0) ?? '',
          q.notes,
        ]);
      }
    }
    return rows.map((r) => r.map(cell).join(',')).join('\r\n');
  }

  /// Parses a backup. Throws [FormatException] if it isn't one.
  static AppStore parseBackup(String text) {
    final j = jsonDecode(text);
    if (j is! Map) throw const FormatException('Not a backup file');
    final s = AppStore()..applyJson(Map<String, dynamic>.from(j));
    if (s.policies.isEmpty) throw const FormatException('No policies in file');
    return s;
  }

  void replaceWith(AppStore other) {
    policies
      ..clear()
      ..addAll(other.policies);
    quotes
      ..clear()
      ..addAll(other.quotes);
    basis = other.basis;
    currency = other.currency;
    _commit();
  }

  void eraseAll() {
    policies.clear();
    quotes.clear();
    _commit();
  }

  /// Example data with invented carriers. Returns the first policy's id.
  String loadSample() {
    final now = DateTime.now();
    final t = now.millisecondsSinceEpoch;
    DateTime ago(int months) => DateTime(now.year, now.month - months, min(now.day, 28));
    DateTime ahead(int days) => today().add(Duration(days: days));

    final car = Policy(id: newId(), name: '2020 Honda CR-V', type: PolicyType.auto,
        carrier: 'Northwind Mutual', renewal: ahead(24),
        notes: 'Sample data. Full coverage, 2 drivers.', created: t);
    final home = Policy(id: newId(), name: 'Elm Street house', type: PolicyType.home,
        carrier: 'Harborline Insurance', renewal: ahead(140), notes: 'Sample data.', created: t + 1);
    final pet = Policy(id: newId(), name: 'Biscuit (dog)', type: PolicyType.pet,
        carrier: 'Bluepine Pet', renewal: ahead(65), notes: 'Sample data.', created: t + 2);

    var n = 0;
    Quote q(Policy p, String c, double a, BillingPeriod per, int m, double d, [String notes = '']) =>
        Quote(id: newId(), policyId: p.id, carrier: c, amount: a, period: per,
            date: ago(m), deductible: d, notes: notes, created: t + (n++));

    const mo = BillingPeriod.month, half = BillingPeriod.half, yr = BillingPeriod.year;
    policies
      ..clear()
      ..addAll([car, home, pet]);
    quotes
      ..clear()
      ..addAll([
        q(car, 'Northwind Mutual', 712, half, 18, 500),
        q(car, 'Northwind Mutual', 768, half, 12, 500),
        q(car, 'Northwind Mutual', 845, half, 6, 500, 'Renewal increase'),
        q(car, 'Northwind Mutual', 902, half, 0, 500, 'Upcoming renewal offer'),
        q(car, 'Keystone Auto Club', 139, mo, 2, 500, 'Bundles with roadside'),
        q(car, 'Harborline Insurance', 821, half, 1, 1000),
        q(car, 'Cedar & Main', 171, mo, 0, 500),
        q(home, 'Harborline Insurance', 1640, yr, 24, 1500),
        q(home, 'Harborline Insurance', 1785, yr, 12, 1500),
        q(home, 'Harborline Insurance', 1932, yr, 0, 1500),
        q(home, 'Northwind Mutual', 1810, yr, 1, 1000, 'Would bundle with auto'),
        q(home, 'Stonegate Home', 1705, yr, 0, 2500),
        q(pet, 'Bluepine Pet', 38.5, mo, 10, 250),
        q(pet, 'Bluepine Pet', 44.2, mo, 0, 250),
        q(pet, 'Pawsure', 41, mo, 0, 500),
      ]);
    _commit();
    return car.id;
  }
}

/// Makes the [AppStore] available to the widget tree and rebuilds
/// dependents whenever it changes.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  /// Use in build methods: rebuilds when data changes.
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Use in callbacks and initState: no rebuild dependency.
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
