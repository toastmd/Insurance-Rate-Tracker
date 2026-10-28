import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';

Future<void> showPolicyForm(BuildContext context, {Policy? policy, ValueChanged<String>? onCreated}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => PolicyForm(policy: policy, onCreated: onCreated),
  );
}

class PolicyForm extends StatefulWidget {
  const PolicyForm({super.key, this.policy, this.onCreated});
  final Policy? policy;
  final ValueChanged<String>? onCreated;

  @override
  State<PolicyForm> createState() => _PolicyFormState();
}

class _PolicyFormState extends State<PolicyForm> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late String _carrier;
  late PolicyType _type;
  BillingPeriod _period = BillingPeriod.month;
  DateTime? _renewal;
  String? _error;

  bool get _editing => widget.policy != null;

  @override
  void initState() {
    super.initState();
    final p = widget.policy;
    _name = TextEditingController(text: p?.name ?? '');
    _amount = TextEditingController();
    _notes = TextEditingController(text: p?.notes ?? '');
    _carrier = p?.carrier ?? '';
    _type = p?.type ?? PolicyType.auto;
    _renewal = p?.renewal;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _fail(String message) => setState(() => _error = message);

  void _save() {
    final store = StoreScope.read(context);
    final name = _name.text.trim();
    if (name.isEmpty) return _fail('Give the policy a name, like the car or address it covers.');
    final carrier = _carrier.trim();
    final notes = _notes.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final existing = widget.policy;

    if (existing != null) {
      existing
        ..name = name
        ..type = _type
        ..carrier = carrier
        ..renewal = _renewal
        ..notes = notes;
      store.save();
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Policy saved'), behavior: SnackBarBehavior.floating));
      return;
    }

    double? premium;
    final raw = _amount.text.trim();
    if (raw.isNotEmpty) {
      premium = parseAmount(raw);
      if (premium == null || premium <= 0) {
        return _fail('Enter the premium as a number above zero, or leave it blank.');
      }
      if (carrier.isEmpty) return _fail('Add the current carrier so the premium has someone to belong to.');
    }
    final created = store.addPolicy(
      name: name,
      type: _type,
      carrier: carrier,
      renewal: _renewal,
      notes: notes,
      premium: premium,
      period: _period,
    );
    Navigator.pop(context);
    messenger.showSnackBar(const SnackBar(content: Text('Policy added'), behavior: SnackBarBehavior.floating));
    widget.onCreated?.call(created.id);
  }

  Future<void> _delete() async {
    final p = widget.policy!;
    final store = StoreScope.read(context);
    final n = store.quotesFor(p.id).length;
    final ok = await confirmAction(
      context,
      title: 'Delete this policy?',
      message: '“${p.name}” and its $n ${n == 1 ? 'rate' : 'rates'} will be removed.',
      action: 'Delete policy',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    store.deletePolicy(p.id);
    messenger.showSnackBar(const SnackBar(content: Text('Policy deleted'), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SheetBody(
      title: _editing ? 'Edit policy' : 'New policy',
      children: [
        TextField(
          controller: _name,
          autofocus: !_editing,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. 2021 Toyota RAV4, Main St house',
          ),
        ),
        DropdownButtonFormField<PolicyType>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            for (final t in PolicyType.values)
              DropdownMenuItem(value: t, child: Text('${t.icon}  ${t.label}')),
          ],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        CarrierField(
          options: store.carrierNames(),
          initial: _carrier,
          label: 'Current carrier (optional)',
          hint: 'Who insures this now',
          onChanged: (v) => _carrier = v,
        ),
        if (!_editing)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Current premium (optional)'),
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
        DateField(
          label: 'Renewal date (optional)',
          value: _renewal,
          optional: true,
          onChanged: (d) => setState(() => _renewal = d),
        ),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'Policy number, agent, coverage limits…',
          ),
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
        FilledButton(onPressed: _save, child: Text(_editing ? 'Save changes' : 'Add policy')),
      ],
    );
  }
}
