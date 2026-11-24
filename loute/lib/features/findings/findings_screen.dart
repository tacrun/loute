import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../themes/midnight_hacker.dart';

/// Findings & Evidence - triage, evidence viewer, severity board.
/// Per 1-5-5.md §11.7.
class FindingsScreen extends ConsumerWidget {
  const FindingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MidnightHacker.background,
      appBar: AppBar(
        title: const Text('FINDINGS & EVIDENCE'),
        backgroundColor: MidnightHacker.background,
      ),
      body: Column(
        children: [
          // Severity board
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: MidnightHacker.primary)),
            ),
            child: Row(
              children: [
                _severityChip('CRITICAL', 0, MidnightHacker.negative),
                const SizedBox(width: 8),
                _severityChip('HIGH', 0, const Color(0xFFFF6B6B)),
                const SizedBox(width: 8),
                _severityChip('MEDIUM', 0, MidnightHacker.positive),
                const SizedBox(width: 8),
                _severityChip('LOW', 0, MidnightHacker.primary),
                const SizedBox(width: 8),
                _severityChip('INFO', 0, MidnightHacker.dimGreen),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bug_report_outlined, size: 64, color: MidnightHacker.dimGreen),
                  const SizedBox(height: 16),
                  Text('No findings yet', style: MidnightHacker.heading),
                  const SizedBox(height: 8),
                  Text(
                    'Run capabilities to discover findings',
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

  Widget _severityChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '$label: $count',
        style: MidnightHacker.monoSmall.copyWith(color: color),
      ),
    );
  }
}
