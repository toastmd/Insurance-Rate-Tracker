import 'package:flutter/material.dart';

import 'carriers_screen.dart';
import 'policies_screen.dart';
import 'policy_detail.dart';
import 'settings_screen.dart';

/// Bottom navigation on phones, a side rail with list and detail side by
/// side on tablets (iPad, Android tablets) and wide windows.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String? _selected;

  static const _destinations = [
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Policies'),
    (Icons.account_balance_outlined, Icons.account_balance, 'Carriers'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 840;

      void openPolicy(String id) {
        if (wide) {
          setState(() {
            _selected = id;
            _tab = 0;
          });
        } else {
          setState(() => _tab = 0);
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PolicyDetailScreen(policyId: id)));
        }
      }

      final body = switch (_tab) {
        0 => PoliciesScreen(wide: wide, selectedId: _selected, onSelect: openPolicy),
        1 => CarriersScreen(onBrowsePolicies: () => setState(() => _tab = 0)),
        _ => SettingsScreen(onSampleLoaded: openPolicy),
      };

      if (wide) {
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.9,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
                  ],
                ),
                VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
                Expanded(child: body),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
          ],
        ),
      );
    });
  }
}
