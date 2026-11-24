import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../themes/midnight_hacker.dart';

/// Jobs / Live Runs - queue, running, streaming, cancel/retry.
/// Per 1-5-5.md §11.6.
class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MidnightHacker.background,
      appBar: AppBar(
        title: const Text('JOBS / LIVE RUNS'),
        backgroundColor: MidnightHacker.background,
      ),
      body: Column(
        children: [
          // Job status bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: MidnightHacker.primary)),
            ),
            child: Row(
              children: [
                _statusChip('QUEUED', 0, MidnightHacker.dimGreen),
                const SizedBox(width: 8),
                _statusChip('RUNNING', 0, MidnightHacker.positive),
                const SizedBox(width: 8),
                _statusChip('COMPLETED', 0, MidnightHacker.primary),
                const SizedBox(width: 8),
                _statusChip('FAILED', 0, MidnightHacker.negative),
              ],
            ),
          ),
          // Empty state
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.terminal, size: 64, color: MidnightHacker.dimGreen),
                  const SizedBox(height: 16),
                  Text('No active jobs', style: MidnightHacker.heading),
                  const SizedBox(height: 8),
                  Text(
                    'Run a capability to see live execution here',
                    style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: MidnightHacker.monoSmall.copyWith(color: color)),
          Text('$count', style: MidnightHacker.monoSmall.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
