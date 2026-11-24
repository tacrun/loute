import 'package:flutter/material.dart';
import '../themes/midnight_hacker.dart';

/// Collapsible accordion - outline icon toggle for phase/module trees.
class CollapsibleAccordion extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Color titleColor;

  const CollapsibleAccordion({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
    this.titleColor = MidnightHacker.primary,
  });

  @override
  State<CollapsibleAccordion> createState() => _CollapsibleAccordionState();
}

class _CollapsibleAccordionState extends State<CollapsibleAccordion> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.keyboard_arrow_down_outlined : Icons.keyboard_arrow_right_outlined,
                  color: widget.titleColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: MidnightHacker.label.copyWith(color: widget.titleColor),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}
