import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';

Future<void> showQuoteForm(BuildContext context, {required String policyId, Quote? quote}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => QuoteForm(policyId: policyId, quote: quote),
  );
}

class QuoteForm extends StatefulWidget {
  const QuoteForm({super.key, required this.policyId, this.quote});
  final String policyId;
  final Quote? quote;

  @override
  State<QuoteForm> createState() => _QuoteFormState();
}

class _QuoteFormState extends State<QuoteForm> {
  late final TextEditingController _amount;
  late final TextEditingController _deductible;
  late final TextEditingController _notes;
  late String _carrier;
  late BillingPeriod _period;
  late DateTime _date;
  late bool _isCurrent;
  String? _error;

  bool get _editing => widget.quote != null;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final q = widget.quote;
    final p = store.policyById(widget.policyId);
    final previous = store.quotesFor(widget.policyId);
    _carrier = q?.carrier ?? '';
    _amount = TextEditingController(text: q == null ? '' : _plain(q.amount));
    _deductible = TextEditingController(text: q?.deductible == null ? '' : _plain(q!.deductible!));
    _notes = TextEditingController(text: q?.notes ?? '');
    _period = q?.period ?? (previous.isEmpty ? BillingPeriod.month : previous.last.period);
    _date = q?.date ?? today();
    _isCurrent = q != null
        ? carrierKey(q.carrier) == carrierKey(p?.carrier ?? '')
        : (p?.carrier ?? '').isEmpty;
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _amount.dispose();
    _deductible.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _fail(String message) => setState(() => _error = message);

  void _save() {
    final store = StoreScope.read(context);
    final carrier = _carrier.trim();
    if (carrier.isEmpty) return _fail('Enter the insurance company’s name.');
    final amount = parseAmount(_amount.text.trim());
    if (amount == null || amount <= 0) return _fail('Enter the premium as a number above zero.');
    double? deductible;
    final dRaw = _deductible.text.trim();
    if (dRaw.isNotEmpty) {
      deductible = parseAmount(dRaw);
      if (deductible == null || deductible < 0) return _fail('Deductible must be a number, or leave it blank.');
    }
    final notes = _notes.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final existing = widget.quote;
    if (existing != null) {
      existing
        ..carrier = carrier
        ..amount = amount
        ..period = _period
        ..date = _date
        ..deductible = deductible
        ..notes = notes;
      store.updateQuote(existing, makeCurrent: _isCurrent);
    } else {
      store.addQuote(
        Quote(
          id: newId(),
          policyId: widget.policyId,
          carrier: carrier,
          amount: amount,
          period: _period,
          date: _date,
          deductible: deductible,
          notes: notes,
          created: DateTime.now().millisecondsSinceEpoch,
        ),
        makeCurrent: _isCurrent,
      );
    }
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(_editing ? 'Rate saved' : 'Rate added'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _delete() async {
    final q = widget.quote!;
    final store = StoreScope.read(context);
    final ok = await confirmAction(
      context,
      title: 'Delete this rate?',
      message: '${q.carrier}, ${store.money(q.amount, decimals: 2)} ${q.period.label.toLowerCase()}, from ${fmtDate(q.date)}.',
      action: 'Delete rate',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    store.deleteQuote(q.id);
    messenger.showSnackBar(const SnackBar(content: Text('Rate deleted'), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final policy = store.policyById(widget.policyId);
    return SheetBody(
      title: _editing ? 'Edit rate' : 'Add a rate for ${policy?.name ?? 'this policy'}',
      children: [
        CarrierField(
          options: store.carrierNames(),
          initial: _carrier,
          label: 'Carrier',
          hint: 'Insurance company',
          autofocus: !_editing,
          onChanged: (v) => _carrier = v,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Premium'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<BillingPeriod>(
                value: _period,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Billed'),
                items: [
                  for (final p in BillingPeriod.values)
                    DropdownMenuItem(value: p, child: Text(p.label, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _period = v ?? _period),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DateField(
                label: 'Quote or bill date',
                value: _date,
                onChanged: (d) => setState(() => _date = d ?? _date),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _deductible,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Deductible (optional)'),
              ),
            ),
          ],
        ),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Coverage notes (optional)',
            hintText: 'Limits, discounts, what’s included…',
          ),
        ),
        CheckboxListTile(
          value: _isCurrent,
          onChanged: (v) => setState(() => _isCurrent = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('This is my current carrier for this policy'),
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
      ],
      actions: [
        if (_editing)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Delete'),
          ),
        const Spacer(),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        const SizedBox(width: 8),
        FilledButton(onPressed: _save, child: const Text('Save rate')),
      ],
    );
  }
}
