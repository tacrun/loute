import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../themes/midnight_hacker.dart';

/// Operations Dashboard - live campaign state, active jobs, top findings, provider health.
/// Per 1-5-5.md §11.1.
class OpsDashboardScreen extends ConsumerWidget {
  const OpsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MidnightHacker.background,
      appBar: AppBar(
        title: const Text('OPERATIONS DASHBOARD'),
        backgroundColor: MidnightHacker.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: MidnightHacker.primary),
              ),
              child: Row(
                children: [
                  Text('LOUTE V1.5.5', style: MidnightHacker.headingLarge.copyWith(fontSize: 24)),
                  const Spacer(),
                  Text('AUTONOMOUS BUG BOUNTY FRAMEWORK',
                      style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Stats grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _statCard('CAPABILITIES', '241', Icons.flash_on),
                  _statCard('PHASES', '11', Icons.layers),
                  _statCard('ACTIVE JOBS', '0', Icons.play_arrow),
                  _statCard('FINDINGS', '0', Icons.bug_report),
                  _statCard('ASSETS', '0', Icons.storage),
                  _statCard('PROVIDERS', '0', Icons.dns),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: MidnightHacker.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: MidnightHacker.dimGreen, size: 16),
              const SizedBox(width: 8),
              Text(label, style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: MidnightHacker.heading.copyWith(fontSize: 28)),
        ],
      ),
    );
  }
}
