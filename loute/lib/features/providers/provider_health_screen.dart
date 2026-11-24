import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../themes/midnight_hacker.dart';

/// Provider Health Matrix - per-provider availability, versions, install hints.
/// Per 1-5-5.md §11.4.
class ProviderHealthScreen extends ConsumerWidget {
  const ProviderHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MidnightHacker.background,
      appBar: AppBar(
        title: const Text('PROVIDER HEALTH MATRIX'),
        backgroundColor: MidnightHacker.background,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.health_and_safety_outlined,
                size: 64, color: MidnightHacker.primary),
            const SizedBox(height: 16),
            Text(
              'Provider Health Matrix',
              style: MidnightHacker.heading,
            ),
            const SizedBox(height: 8),
            Text(
              'Probe provider binaries and view availability states',
              style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh),
              label: const Text('PROBE NOW'),
            ),
          ],
        ),
      ),
    );
  }
}
