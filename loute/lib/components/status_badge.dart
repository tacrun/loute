import 'package:flutter/material.dart';
import '../themes/midnight_hacker.dart';

/// Status badge - inline text: [LIVE], [DEAD], [SAFE], [VULNERABLE]
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const StatusBadge({super.key, required this.text, required this.color});

  const StatusBadge.live({super.key})
      : text = '[LIVE]',
        color = MidnightHacker.positive;

  const StatusBadge.dead({super.key})
      : text = '[DEAD]',
        color = MidnightHacker.negative;

  const StatusBadge.safe({super.key})
      : text = '[SAFE]',
        color = MidnightHacker.primary;

  const StatusBadge.vulnerable({super.key})
      : text = '[VULNERABLE]',
        color = MidnightHacker.positive;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: MidnightHacker.monoStyle.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
