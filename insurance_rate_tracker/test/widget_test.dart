import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_rate_tracker/format.dart';
import 'package:insurance_rate_tracker/models.dart';
import 'package:insurance_rate_tracker/screens/home_screen.dart';
import 'package:insurance_rate_tracker/store.dart';

Quote _q(String pid, String carrier, double amount, BillingPeriod period, [DateTime? date]) => Quote(
      id: newId(),
      policyId: pid,
      carrier: carrier,
      amount: amount,
      period: period,
      date: date ?? today(),
      created: DateTime.now().microsecondsSinceEpoch,
    );

void main() {
  test('annualizes each billing period', () {
    expect(_q('p', 'A', 100, BillingPeriod.month).annual, 1200);
    expect(_q('p', 'A', 100, BillingPeriod.quarter).annual, 400);
    expect(_q('p', 'A', 100, BillingPeriod.half).annual, 200);
    expect(_q('p', 'A', 100, BillingPeriod.year).annual, 100);
  });

  test('finds the lowest quote and the savings', () {
    final s = AppStore();
    final p = s.addPolicy(name: 'Car', type: PolicyType.auto, carrier: 'Alpha', premium: 100);
    s.addQuote(_q(p.id, 'Beta', 1000, BillingPeriod.year));
    s.addQuote(_q(p.id, 'Gamma', 600, BillingPeriod.half));
    final st = s.stats(p);
    expect(st.current!.carrier, 'Alpha');
    expect(st.best!.carrier, 'Beta');
    expect(st.savings, closeTo(200, 0.001));
  });

  test('tracks the change in the current carrier\'s rate', () {
    final s = AppStore();
    final p = s.addPolicy(name: 'Home', type: PolicyType.home, carrier: 'alpha');
    s.addQuote(_q(p.id, 'Alpha', 1000, BillingPeriod.year, DateTime(2025, 1, 1)));
    s.addQuote(_q(p.id, 'Alpha ', 1100, BillingPeriod.year, DateTime(2026, 1, 1)));
    expect(s.stats(p).change, closeTo(10, 0.001));
  });

  test('backups round-trip', () {
    final s = AppStore()..loadSample();
    final copy = AppStore.parseBackup(jsonEncode(s.toJson()));
    expect(copy.policies.length, s.policies.length);
    expect(copy.quotes.length, s.quotes.length);
    expect(() => AppStore.parseBackup('[]'), throwsFormatException);
  });

  testWidgets('shows the empty state on first launch', (tester) async {
    final store = AppStore();
    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: HomeScreen())));
    expect(find.text('Try with sample data'), findsOneWidget);
    await tester.tap(find.text('Try with sample data'));
    await tester.pumpAndSettle();
    expect(store.policies.length, 3);
  });
}
