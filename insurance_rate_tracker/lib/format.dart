import 'package:intl/intl.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime today() => dateOnly(DateTime.now());

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseIso(String? s) {
  if (s == null || s.isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// Whole days from today to [d]. Negative when [d] is in the past.
int daysUntil(DateTime d) {
  final n = DateTime.now();
  return DateTime.utc(d.year, d.month, d.day)
      .difference(DateTime.utc(n.year, n.month, n.day))
      .inDays;
}

String fmtDate(DateTime d) => DateFormat.yMMMd().format(d);
String fmtShortDate(DateTime d) => DateFormat('MMM yy').format(d);

String formatMoney(double v, String currency, int decimals) {
  try {
    return NumberFormat.simpleCurrency(name: currency, decimalDigits: decimals)
        .format(v);
  } catch (_) {
    return '$currency ${v.toStringAsFixed(decimals)}';
  }
}

/// Parses "1,234.50", "$99" and similar. Returns null if not a finite number.
double? parseAmount(String s) {
  final v = double.tryParse(s.replaceAll(RegExp(r'[,\s$€£¥]'), ''));
  return v != null && v.isFinite ? v : null;
}
