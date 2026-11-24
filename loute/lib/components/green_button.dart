import 'package:flutter/material.dart';
import '../themes/midnight_hacker.dart';
import 'spinning_dots.dart';

/// Green outlined button - the standard LOUTE button.
/// Variants: primary (green), danger (red), positive (amber).
class GreenButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;
  final bool expanded;
  final bool isFilled;
  final bool isLoading;

  const GreenButton({
    super.key,
    required this.label,
    this.onPressed,
    this.borderColor = MidnightHacker.primary,
    this.textColor = MidnightHacker.primary,
    this.icon,
    this.expanded = false,
    this.isFilled = false,
    this.isLoading = false,
  });

  const GreenButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = false,
    this.isFilled = false,
    this.isLoading = false,
  })  : borderColor = MidnightHacker.negative,
        textColor = MidnightHacker.negative;

  const GreenButton.positive({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = false,
    this.isFilled = false,
    this.isLoading = false,
  })  : borderColor = MidnightHacker.positive,
        textColor = MidnightHacker.positive;

  @override
  State<GreenButton> createState() => _GreenButtonState();
}

class _GreenButtonState extends State<GreenButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.isFilled ? widget.borderColor : widget.textColor;
    final effectiveBgColor = widget.isFilled ? widget.borderColor : Colors.transparent;
    final effectiveTextColor = widget.isFilled ? MidnightHacker.background : effectiveColor;

    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: OutlinedButton(
        onPressed: widget.onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: effectiveTextColor,
          backgroundColor: effectiveBgColor,
          side: BorderSide(
            color: widget.borderColor,
            width: _hovering && !widget.isFilled ? 2 : 1,
          ),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null && !widget.isLoading) ...[
                Icon(widget.icon, size: 18, color: effectiveTextColor),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label, 
                style: MidnightHacker.label.copyWith(color: effectiveTextColor)
              ),
              if (widget.isLoading) ...[
                const SizedBox(width: 8),
                SpinningDotsIndicator(color: effectiveTextColor, fontSize: 16),
              ],
            ],
          ),
        ),
      ),
    );
    return widget.expanded ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
