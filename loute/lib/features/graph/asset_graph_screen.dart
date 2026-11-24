import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../themes/midnight_hacker.dart';

/// Asset Graph - canvas + list, pivot actions.
/// Per 1-5-5.md §11.7.
class AssetGraphScreen extends ConsumerWidget {
  const AssetGraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MidnightHacker.background,
      appBar: AppBar(
        title: const Text('ASSET GRAPH'),
        backgroundColor: MidnightHacker.background,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_tree_outlined, size: 64, color: MidnightHacker.dimGreen),
            const SizedBox(height: 16),
            Text('Asset Graph', style: MidnightHacker.heading),
            const SizedBox(height: 8),
            Text(
              'Visualize asset relationships and attack paths',
              style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              children: [
                _pivotButton('SCAN', Icons.radar),
                _pivotButton('FINGERPRINT', Icons.fingerprint),
                _pivotButton('VULN', Icons.bug_report),
                _pivotButton('EXPLOIT', Icons.security),
                _pivotButton('CRED', Icons.key),
                _pivotButton('LATERAL', Icons.swap_horiz),
                _pivotButton('PERSIST', Icons.push_pin),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pivotButton(String label, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 16),
      label: Text(label, style: MidnightHacker.monoSmall),
    );
  }
}
