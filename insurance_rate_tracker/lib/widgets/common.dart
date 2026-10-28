import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../theme.dart';

/// A white rounded card with a hairline border.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class PanelHeading extends StatelessWidget {
  const PanelHeading(this.title, {super.key, this.hint});
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

enum ChipKind { neutral, good, bad, brand }

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.kind = ChipKind.neutral});
  final String label;
  final ChipKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rc = context.rc;
    final (bg, fg) = switch (kind) {
      ChipKind.good => (rc.downSoft, rc.down),
      ChipKind.bad => (rc.upSoft, rc.up),
      ChipKind.brand => (rc.brandSoft, scheme.primary),
      ChipKind.neutral => (scheme.surfaceContainerLow, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
    );
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type, this.size = 44});
  final PolicyType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.rc.brandSoft,
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Text(type.icon, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

class FactBox extends StatelessWidget {
  const FactBox({super.key, required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: valueColor)),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// Tappable field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.optional = false,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: v ?? today(),
          firstDate: DateTime(1990),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(dateOnly(picked));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: optional && v != null
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear date',
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(v == null ? 'Not set' : fmtDate(v)),
      ),
    );
  }
}

/// Text field that suggests carriers already entered elsewhere.
class CarrierField extends StatelessWidget {
  const CarrierField({
    super.key,
    required this.options,
    required this.initial,
    required this.onChanged,
    required this.label,
    this.hint,
    this.autofocus = false,
  });
  final List<String> options;
  final String initial;
  final ValueChanged<String> onChanged;
  final String label;
  final String? hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initial),
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return options.where((o) => o.toLowerCase().contains(q) && o.toLowerCase() != q);
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: onChanged,
      ),
    );
  }
}

/// Layout for the add and edit bottom sheets.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.title, required this.children, required this.actions});
  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spaced = <Widget>[];
    for (final c in children) {
      if (spaced.isNotEmpty) spaced.add(const SizedBox(height: 14));
      spaced.add(c);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(children: actions),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centers content and caps its width on tablets.
EdgeInsets centeredPadding(double width, {double maxContent = 760, double vertical = 16}) {
  final side = width > maxContent + 32 ? (width - maxContent) / 2 : 16.0;
  return EdgeInsets.fromLTRB(side, vertical, side, vertical + 16);
}
