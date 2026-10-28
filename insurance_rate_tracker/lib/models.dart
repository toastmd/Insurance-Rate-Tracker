import 'dart:math';

import 'format.dart';

enum PolicyType {
  auto('Auto', '🚗'),
  home('Home', '🏠'),
  renters('Renters', '🔑'),
  condo('Condo', '🏢'),
  life('Life', '🌱'),
  health('Health', '🩺'),
  dental('Dental & vision', '🦷'),
  pet('Pet', '🐾'),
  umbrella('Umbrella', '☂️'),
  recreational('Motorcycle, boat or RV', '🏍️'),
  business('Business', '💼'),
  other('Other', '📄');

  const PolicyType(this.label, this.icon);
  final String label;
  final String icon;

  static PolicyType parse(Object? s) =>
      PolicyType.values.firstWhere((t) => t.name == s, orElse: () => PolicyType.other);
}

enum BillingPeriod {
  month('Monthly', 12),
  quarter('Quarterly', 4),
  half('Every 6 months', 2),
  year('Yearly', 1);

  const BillingPeriod(this.label, this.factor);
  final String label;
  final int factor;

  static BillingPeriod parse(Object? s) => BillingPeriod.values
      .firstWhere((p) => p.name == s, orElse: () => BillingPeriod.month);
}

/// Whether prices are shown per month or per year.
enum Basis { month, year }

final _rand = Random();
String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    _rand.nextInt(0x7fffffff).toRadixString(36);

/// Carriers are matched case-insensitively, ignoring outer spaces.
String carrierKey(String s) => s.trim().toLowerCase();

String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

double? _num(Object? v) {
  if (v is num) return v.toDouble().isFinite ? v.toDouble() : null;
  if (v is String && v.trim().isNotEmpty) return parseAmount(v);
  return null;
}

class Policy {
  Policy({
    required this.id,
    required this.name,
    required this.type,
    this.carrier = '',
    this.renewal,
    this.notes = '',
    required this.created,
  });

  final String id;
  String name;
  PolicyType type;

  /// The carrier currently insuring this policy. Empty if none.
  String carrier;
  DateTime? renewal;
  String notes;
  final int created;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'carrier': carrier,
        'renewal': renewal == null ? '' : isoDate(renewal!),
        'notes': notes,
        'created': created,
      };

  static Policy? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final name = j['name'];
    if (id == null || name is! String || name.trim().isEmpty) return null;
    return Policy(
      id: id.toString(),
      name: _cut(name.trim(), 120),
      type: PolicyType.parse(j['type']),
      carrier: _cut((j['carrier'] ?? '').toString().trim(), 80),
      renewal: parseIso(j['renewal']?.toString()),
      notes: _cut((j['notes'] ?? '').toString(), 1000),
      created: _num(j['created'])?.toInt() ?? 0,
    );
  }
}

class Quote {
  Quote({
    required this.id,
    required this.policyId,
    required this.carrier,
    required this.amount,
    required this.period,
    required this.date,
    this.deductible,
    this.notes = '',
    required this.created,
  });

  final String id;
  final String policyId;
  String carrier;

  /// Amount per billing period, e.g. 845 every 6 months.
  double amount;
  BillingPeriod period;

  /// Date of the quote or bill.
  DateTime date;
  double? deductible;
  String notes;
  final int created;

  double get annual => amount * period.factor;

  Map<String, dynamic> toJson() => {
        'id': id,
        'policyId': policyId,
        'carrier': carrier,
        'amount': amount,
        'period': period.name,
        'date': isoDate(date),
        'deductible': deductible,
        'notes': notes,
        'created': created,
      };

  static Quote? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final pid = j['policyId'];
    final amount = _num(j['amount']);
    if (id == null || pid == null || amount == null || amount < 0) return null;
    return Quote(
      id: id.toString(),
      policyId: pid.toString(),
      carrier: _cut((j['carrier'] ?? '').toString().trim(), 80),
      amount: amount,
      period: BillingPeriod.parse(j['period']),
      date: parseIso(j['date']?.toString()) ?? today(),
      deductible: _num(j['deductible']),
      notes: _cut((j['notes'] ?? '').toString(), 600),
      created: _num(j['created'])?.toInt() ?? 0,
    );
  }
}
