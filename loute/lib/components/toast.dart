import 'package:flutter/material.dart';
import '../themes/midnight_hacker.dart';

enum ToastType { info, success, error }

/// Show a toast notification - top-right, auto-dismiss 3s.
void showLouteToast(BuildContext context, String message, {ToastType type = ToastType.info}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  final color = switch (type) {
    ToastType.info => MidnightHacker.primary,
    ToastType.success => MidnightHacker.positive,
    ToastType.error => MidnightHacker.negative,
  };

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MidnightHacker.background,
            border: Border.all(color: color, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                switch (type) {
                  ToastType.info => Icons.info_outline,
                  ToastType.success => Icons.check_circle_outline,
                  ToastType.error => Icons.error_outline,
                },
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(message, style: MidnightHacker.monoSmall.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), () => entry.remove());
}
