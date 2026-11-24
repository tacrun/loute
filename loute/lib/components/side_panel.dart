import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/midnight_hacker.dart';
import '../models/catalog_ui.dart';
import '../providers/navigation_state.dart';

/// The sidebar is the only real navigation surface. It shows the Start actions,
/// the eleven catalog phases with their capabilities, and a bottom utility rail.
class SidePanel extends ConsumerWidget {
  const SidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(navigationProvider).sidePanelCollapsed;
    return collapsed
        ? const _CollapsedPanel()
        : const _ExpandedPanel();
  }
}

class _ExpandedPanel extends ConsumerWidget {
  const _ExpandedPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationProvider);
    final notifier = ref.read(navigationProvider.notifier);

    return Container(
      width: 272,
      decoration: const BoxDecoration(
        color: MidnightHacker.panelBg,
        border: Border(right: MidnightHacker.greenBorder),
      ),
      child: Column(
        children: [
          // Collapse control. It replaces the old header toggle.
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: MidnightHacker.greenBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal_outlined, color: MidnightHacker.primary, size: 16),
                const SizedBox(width: 8),
                Text('LOUTE / CONTROL', style: MidnightHacker.monoSmall.copyWith(letterSpacing: 1)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left_outlined, color: MidnightHacker.primary, size: 18),
                  tooltip: 'Collapse Sidebar',
                  onPressed: notifier.toggleSidePanelCollapsed,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Start section: Dashboard and the OS-aware tool manager.
          _NavRow(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            active: nav.activeScreen == ActiveScreen.dashboard,
            onTap: () => notifier.setActiveScreen(ActiveScreen.dashboard),
          ),
          _NavRow(
            label: 'Tool Manager',
            icon: Icons.build_outlined,
            active: nav.activeScreen == ActiveScreen.toolManager,
            onTap: () => notifier.setActiveScreen(ActiveScreen.toolManager),
          ),

          const Divider(),

          // Phase tree. No section heading; phases are self describing.
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: CatalogUi.phases.length,
              itemBuilder: (context, index) {
                final info = CatalogUi.phases[index];
                final expanded = nav.expandedPhases.contains(info.id);
                final caps = CatalogUi.capabilitiesIn(info.phase);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PhaseRow(
                      label: info.shortName,
                      icon: info.icon,
                      count: caps.length,
                      expanded: expanded,
                      onTap: () => notifier.togglePhaseExpanded(info.id),
                    ),
                    if (expanded)
                      ...caps.map((cap) => _CapabilityRow(
                            label: cap.label,
                            icon: CatalogUi.iconFor(cap),
                            selected: nav.selectedCapabilityId == cap.id &&
                                nav.activeScreen == ActiveScreen.capability,
                            onTap: () => notifier.selectCapability(info.id, cap.id),
                          )),
                  ],
                );
              },
            ),
          ),

          const Divider(),

          // Utility rail.
          _NavRow(
            label: 'Settings',
            icon: Icons.settings_outlined,
            active: nav.activeScreen == ActiveScreen.settings,
            onTap: () => notifier.setActiveScreen(ActiveScreen.settings),
          ),
          _NavRow(
            label: 'Reports',
            icon: Icons.assessment_outlined,
            active: nav.activeScreen == ActiveScreen.reports,
            onTap: () => notifier.setActiveScreen(ActiveScreen.reports),
          ),
          _NavRow(
            label: 'Documentation',
            icon: Icons.menu_book_outlined,
            active: nav.activeScreen == ActiveScreen.documentation,
            onTap: () => notifier.setActiveScreen(ActiveScreen.documentation),
          ),
        ],
      ),
    );
  }
}

class _CollapsedPanel extends ConsumerWidget {
  const _CollapsedPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationProvider);
    final notifier = ref.read(navigationProvider.notifier);

    return Container(
      width: 58,
      decoration: const BoxDecoration(
        color: MidnightHacker.panelBg,
        border: Border(right: MidnightHacker.greenBorder),
      ),
      child: Column(
        children: [
          _RailIcon(
            icon: Icons.chevron_right_outlined,
            tooltip: 'Expand Sidebar',
            onTap: notifier.toggleSidePanelCollapsed,
          ),
          const Divider(),
          _RailIcon(
            icon: Icons.dashboard_outlined,
            tooltip: 'Dashboard',
            active: nav.activeScreen == ActiveScreen.dashboard,
            onTap: () => notifier.setActiveScreen(ActiveScreen.dashboard),
          ),
          _RailIcon(
            icon: Icons.build_outlined,
            tooltip: 'Tool Manager',
            active: nav.activeScreen == ActiveScreen.toolManager,
            onTap: () => notifier.setActiveScreen(ActiveScreen.toolManager),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: CatalogUi.phases.length,
              itemBuilder: (context, index) {
                final info = CatalogUi.phases[index];
                return _RailIcon(
                  icon: info.icon,
                  tooltip: info.shortName,
                  active: nav.selectedPhaseId == info.id,
                  onTap: () {
                    notifier.expandPhase(info.id);
                    notifier.toggleSidePanelCollapsed();
                  },
                );
              },
            ),
          ),
          const Divider(),
          _RailIcon(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => notifier.setActiveScreen(ActiveScreen.settings),
          ),
          _RailIcon(
            icon: Icons.assessment_outlined,
            tooltip: 'Reports',
            onTap: () => notifier.setActiveScreen(ActiveScreen.reports),
          ),
          _RailIcon(
            icon: Icons.menu_book_outlined,
            tooltip: 'Documentation',
            onTap: () => notifier.setActiveScreen(ActiveScreen.documentation),
          ),
        ],
      ),
    );
  }
}

class _PhaseRow extends StatefulWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _PhaseRow({
    required this.label,
    required this.icon,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  State<_PhaseRow> createState() => _PhaseRowState();
}

class _PhaseRowState extends State<_PhaseRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 10, top: 9, bottom: 9),
          color: _hover ? MidnightHacker.primary.withOpacity(0.06) : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                size: 16,
                color: widget.expanded ? MidnightHacker.primary : MidnightHacker.dimGreen,
              ),
              const SizedBox(width: 4),
              Icon(widget.icon,
                  size: 17,
                  color: widget.expanded ? MidnightHacker.primary : MidnightHacker.dimGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: MidnightHacker.monoSmall.copyWith(
                    color: widget.expanded ? MidnightHacker.primary : MidnightHacker.dimGreen,
                    fontWeight: widget.expanded ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text('${widget.count}',
                  style: MidnightHacker.monoSmall.copyWith(
                    color: MidnightHacker.dimGreen, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityRow extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CapabilityRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_CapabilityRow> createState() => _CapabilityRowState();
}

class _CapabilityRowState extends State<_CapabilityRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.only(left: 36, right: 10, top: 7, bottom: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? MidnightHacker.primary.withOpacity(0.12)
                : (_hover ? MidnightHacker.primary.withOpacity(0.05) : Colors.transparent),
            border: Border(
              left: widget.selected
                  ? MidnightHacker.greenBorderThick
                  : const BorderSide(color: Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 15,
                  color: widget.selected ? MidnightHacker.positive : MidnightHacker.dimGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: MidnightHacker.monoSmall.copyWith(
                    color: widget.selected ? MidnightHacker.positive : MidnightHacker.dimGreen,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavRow({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              left: widget.active
                  ? MidnightHacker.greenBorderThick
                  : const BorderSide(color: Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 18,
                  color: widget.active ? MidnightHacker.positive : MidnightHacker.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label.toUpperCase(),
                  style: MidnightHacker.monoSmall.copyWith(
                    color: widget.active
                        ? MidnightHacker.primary
                        : (_hover ? MidnightHacker.primary : MidnightHacker.dimGreen),
                    fontWeight: widget.active ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _RailIcon({
    required this.icon,
    required this.tooltip,
    this.active = false,
    required this.onTap,
  });

  @override
  State<_RailIcon> createState() => _RailIconState();
}

class _RailIconState extends State<_RailIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            height: 46,
            decoration: BoxDecoration(
              border: Border(
                left: widget.active
                    ? MidnightHacker.greenBorderThick
                    : const BorderSide(color: Colors.transparent, width: 2),
              ),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: widget.active
                  ? MidnightHacker.positive
                  : (_hover ? MidnightHacker.primary : MidnightHacker.dimGreen),
            ),
          ),
        ),
      ),
    );
  }
}
