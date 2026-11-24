import 'package:flutter/material.dart';
import '../themes/midnight_hacker.dart';

/// Modal dialog - rectangular, green border, black bg.
class LouteDialog extends StatelessWidget {
  final String title;
  final String message;
  final Color titleColor;
  final List<Widget> actions;

  const LouteDialog({
    super.key,
    required this.title,
    required this.message,
    this.titleColor = MidnightHacker.positive,
    this.actions = const [],
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String message,
    Color titleColor = MidnightHacker.positive,
    List<Widget> actions = const [],
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => LouteDialog(
        title: title,
        message: message,
        titleColor: titleColor,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < 768 ? width * 0.05 : (width - 500) / 2,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MidnightHacker.background,
          border: Border.all(color: MidnightHacker.primary, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: MidnightHacker.heading.copyWith(color: titleColor)),
                IconButton(
                  icon: const Icon(Icons.close_outlined, color: MidnightHacker.primary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(message, style: MidnightHacker.monoStyle),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions.map((a) => Padding(padding: const EdgeInsets.only(left: 8), child: a)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
