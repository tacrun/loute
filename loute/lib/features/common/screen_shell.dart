import 'package:flutter/material.dart';
import '../../themes/midnight_hacker.dart';

/// Shared Midnight Hacker screen shell for all V1.5.5 operator screens (§11).
class ScreenShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget body;
  final List<Widget>? actions;

  const ScreenShell({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightHacker.background,
      appBar: AppBar(
        title: Text(title, style: MidnightHacker.heading),
        backgroundColor: MidnightHacker.background,
        actions: actions,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('LOUTE V1.5.5',
                    style: MidnightHacker.headingLarge.copyWith(fontSize: 20)),
                const SizedBox(width: 12),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: MidnightHacker.labelDim),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// A bordered data card consistent with the Midnight Hacker theme.
class DataCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? accent;

  const DataCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: accent ?? MidnightHacker.primary)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, color: accent ?? MidnightHacker.primary, size: 20),
          const SizedBox(height: 6),
          Text(title, style: MidnightHacker.labelDim),
          Text(value, style: MidnightHacker.heading.copyWith(fontSize: 18)),
        ],
      ),
    );
  }
}
