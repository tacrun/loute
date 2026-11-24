import 'package:flutter/material.dart';
import '../themes/midnight_hacker.dart';

/// Scrollable terminal log viewer - real-time scan output.
class TerminalLog extends StatelessWidget {
  final List<String> lines;
  final ScrollController? scrollController;

  const TerminalLog({super.key, required this.lines, this.scrollController});

  Color _lineColor(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('error') || lower.contains('failed') || lower.contains('[dead]')) {
      return MidnightHacker.negative;
    }
    if (lower.contains('vuln') || lower.contains('[live]') || lower.contains('found')) {
      return MidnightHacker.positive;
    }
    return MidnightHacker.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MidnightHacker.background,
        border: Border.all(color: MidnightHacker.primary, width: 1),
      ),
      child: ListView.builder(
        controller: scrollController,
        shrinkWrap: true,
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          return Text(
            '> $line',
            style: MidnightHacker.monoSmall.copyWith(color: _lineColor(line)),
          );
        },
      ),
    );
  }
}
