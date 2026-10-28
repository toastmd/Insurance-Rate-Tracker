import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onSampleLoaded});
  final ValueChanged<String> onSampleLoaded;

  static const currencies = ['USD', 'CAD', 'GBP', 'EUR', 'AUD', 'NZD', 'INR', 'MXN', 'ZAR', 'JPY'];

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final title = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    final sections = <Widget>[
      Panel(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Show prices', style: title),
                Text('Quotes billed any other way are converted.', style: hint),
              ],
            ),
            SegmentedButton<Basis>(
              segments: const [
                ButtonSegment(value: Basis.month, label: Text('Per month')),
                ButtonSegment(value: Basis.year, label: Text('Per year')),
              ],
              selected: {store.basis},
              showSelectedIcon: false,
              onSelectionChanged: (s) => store.setBasis(s.first),
            ),
          ],
        ),
      ),
      Panel(
        child: Row(
          children: [
            Expanded(child: Text('Currency', style: title)),
            DropdownButton<String>(
              value: currencies.contains(store.currency) ? store.currency : null,
              hint: Text(store.currency),
              underline: const SizedBox.shrink(),
              items: [for (final c in currencies) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (c) {
                if (c != null) store.setCurrency(c);
              },
            ),
          ],
        ),
      ),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backup and export', style: title),
            const SizedBox(height: 2),
            Text(
              'Your data is stored on this device. Export a backup to move it to another phone or tablet, or to keep a copy. Backups also work with the web version.',
              style: hint,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Builder(
                  builder: (bctx) => OutlinedButton(
                    onPressed: () => _exportCsv(bctx),
                    child: const Text('Export spreadsheet (CSV)'),
                  ),
                ),
                Builder(
                  builder: (bctx) => OutlinedButton(
                    onPressed: () => _shareFile(
                      bctx,
                      'insurance-rates-backup-${isoDate(today())}.json',
                      StoreScope.read(bctx).exportJson(),
                      'application/json',
                    ),
                    child: const Text('Export backup'),
                  ),
                ),
                OutlinedButton(onPressed: () => _import(context), child: const Text('Import backup')),
              ],
            ),
          ],
        ),
      ),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start over', style: title),
            const SizedBox(height: 2),
            Text('Remove every policy and rate. Export a backup first if you might want them back.', style: hint),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: () => _sample(context), child: const Text('Load sample data')),
                OutlinedButton(
                  onPressed: () => _erase(context),
                  style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: const Text('Erase everything'),
                ),
              ],
            ),
          ],
        ),
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final pad = centeredPadding(c.maxWidth, maxContent: 640, vertical: 0);
      return CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Settings')),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 32),
            sliver: SliverList.separated(
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) => sections[i],
            ),
          ),
        ],
      );
    });
  }

  Future<void> _exportCsv(BuildContext context) async {
    final store = StoreScope.read(context);
    if (store.quotes.isEmpty) {
      showSnack(context, 'Add a rate first, then export.');
      return;
    }
    await _shareFile(context, 'insurance-rates-${isoDate(today())}.csv', store.exportCsv(), 'text/csv');
  }

  /// Writes [text] to a temporary file and opens the system share sheet, so
  /// it can be saved to Files, Drive, email and so on.
  Future<void> _shareFile(BuildContext context, String filename, String text, String mime) async {
    // iPad shows the share sheet as a popover anchored to the tapped button.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(text);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mime)],
        subject: filename,
        sharePositionOrigin: origin,
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn’t create the file. Try again.')));
    }
  }

  Future<void> _import(BuildContext context) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;
      final bytes = f.bytes;
      final path = f.path;
      final String text;
      if (bytes != null) {
        text = utf8.decode(bytes);
      } else if (path != null) {
        text = await File(path).readAsString();
      } else {
        return;
      }
      final parsed = AppStore.parseBackup(text);
      if (!context.mounted) return;
      final ok = await confirmAction(
        context,
        title: 'Replace your data?',
        message:
            'Import ${parsed.policies.length} ${parsed.policies.length == 1 ? 'policy' : 'policies'} and ${parsed.quotes.length} rates. What’s here now will be replaced.',
        action: 'Import',
      );
      if (!ok) return;
      store.replaceWith(parsed);
      messenger.showSnackBar(const SnackBar(content: Text('Backup imported')));
    } on FormatException {
      messenger.showSnackBar(const SnackBar(content: Text('That file isn’t a backup from this app.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn’t read that file.')));
    }
  }

  Future<void> _sample(BuildContext context) async {
    final store = StoreScope.read(context);
    if (store.policies.isNotEmpty) {
      final ok = await confirmAction(
        context,
        title: 'Replace with sample data?',
        message: 'Your current policies and rates will be replaced by examples.',
        action: 'Load sample',
      );
      if (!ok) return;
    }
    final id = store.loadSample();
    onSampleLoaded(id);
  }

  Future<void> _erase(BuildContext context) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Erase everything?',
      message: 'Every policy and rate on this device will be deleted.',
      action: 'Erase everything',
    );
    if (!ok) return;
    store.eraseAll();
    messenger.showSnackBar(const SnackBar(content: Text('Everything erased')));
  }
}
