import 'package:flutter/material.dart';
import '../themes/midnight_hacker.dart';

/// Linear progress bar - green fill, no rounded ends, 1px border.
class ProgressBar extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final bool showPercentage;
  final double height;

  const ProgressBar({
    super.key,
    required this.value,
    this.showPercentage = true,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: MidnightHacker.primary, width: 1),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    width: constraints.maxWidth * value.clamp(0.0, 1.0),
                    color: MidnightHacker.primary,
                  ),
                ],
              );
            },
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(height: 4),
          Text(
            '${(value * 100).toInt()}%',
            style: MidnightHacker.monoSmall,
          ),
        ],
      ],
    );
  }
}
