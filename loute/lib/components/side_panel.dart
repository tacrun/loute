import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/midnight_hacker.dart';
import '../models/phase_registry.dart';
import '../providers/navigation_state.dart';

/// Left side panel - 280px when expanded, 60px when collapsed to a thin icon segment.
class SidePanel extends ConsumerWidget {
  const SidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    final isCollapsed = navState.sidePanelCollapsed;

    if (isCollapsed) {
      return _buildCollapsed(context, ref, navState);
    } else {
      return _buildExpanded(context, ref, navState);
    }
  }

  // Thin icon-only sidebar
  Widget _buildCollapsed(BuildContext context, WidgetRef ref, NavigationState navState) {
    final notifier = ref.read(navigationProvider.notifier);

    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: MidnightHacker.panelBg,
        border: Border(right: MidnightHacker.greenBorder),
      ),
      child: Column(
        children: [
          // Toggle collapse/expand button
          _CollapsedIconItem(
            icon: Icons.chevron_right_outlined,
            tooltip: 'Expand Sidebar',
            onTap: () => notifier.toggleSidePanelCollapsed(),
          ),
          const Divider(),

          // 4 Main Navigation icons
          _CollapsedIconItem(
            icon: Icons.dashboard_outlined,
            tooltip: 'Dashboard',
            active: navState.activeScreen == ActiveScreen.dashboard,
            onTap: () => notifier.setActiveScreen(ActiveScreen.dashboard),
          ),
          _CollapsedIconItem(
            icon: Icons.menu_book_outlined,
            tooltip: 'Documentation',
            active: navState.activeScreen == ActiveScreen.documentation,
            onTap: () => notifier.setActiveScreen(ActiveScreen.documentation),
          ),
          _CollapsedIconItem(
            icon: Icons.assessment_outlined,
            tooltip: 'Reports',
            active: navState.activeScreen == ActiveScreen.reports,
            onTap: () => notifier.setActiveScreen(ActiveScreen.reports),
          ),
          _CollapsedIconItem(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            active: navState.activeScreen == ActiveScreen.settings,
            onTap: () => notifier.setActiveScreen(ActiveScreen.settings),
          ),
          const Divider(),

          // 10 Phase icons
          Expanded(
            child: ListView(
              children: List.generate(PhaseRegistry.phases.length, (index) {
                final phase = PhaseRegistry.phases[index];
                final active = navState.selectedPhaseId == phase.id;

                return _CollapsedIconItem(
                  icon: phase.icon,
                  tooltip: phase.name,
                  active: active,
                  onTap: () {
                    notifier.togglePhaseExpanded(phase.id);
                    notifier.toggleSidePanelCollapsed();
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Expanded panel with headers and phase tree
  Widget _buildExpanded(BuildContext context, WidgetRef ref, NavigationState navState) {
    final notifier = ref.read(navigationProvider.notifier);

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: MidnightHacker.panelBg,
        border: Border(right: MidnightHacker.greenBorder),
      ),
      child: Column(
        children: [
          // Header with collapse toggle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: MidnightHacker.greenBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NAVIGATION',
                  style: MidnightHacker.label.copyWith(letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_outlined, color: MidnightHacker.primary, size: 20),
                  tooltip: 'Collapse Sidebar',
                  onPressed: () => notifier.toggleSidePanelCollapsed(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Main Navigation options
          _ExpandedNavOption(
            label: 'DASHBOARD',
            icon: Icons.dashboard_outlined,
            active: navState.activeScreen == ActiveScreen.dashboard,
            onTap: () => notifier.setActiveScreen(ActiveScreen.dashboard),
          ),
          _ExpandedNavOption(
            label: 'DOCUMENTATION',
            icon: Icons.menu_book_outlined,
            active: navState.activeScreen == ActiveScreen.documentation,
            onTap: () => notifier.setActiveScreen(ActiveScreen.documentation),
          ),
          _ExpandedNavOption(
            label: 'REPORTS EXPLORER',
            icon: Icons.assessment_outlined,
            active: navState.activeScreen == ActiveScreen.reports,
            onTap: () => notifier.setActiveScreen(ActiveScreen.reports),
          ),
          _ExpandedNavOption(
            label: 'SETTINGS PANEL',
            icon: Icons.settings_outlined,
            active: navState.activeScreen == ActiveScreen.settings,
            onTap: () => notifier.setActiveScreen(ActiveScreen.settings),
          ),

          const Divider(),

          // Phase tree header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Text(
              'SCAN PHASES',
              style: MidnightHacker.label.copyWith(letterSpacing: 3, fontSize: 12, color: MidnightHacker.dimGreen),
            ),
          ),

          // Tree View
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: PhaseRegistry.phases.length,
              itemBuilder: (context, index) {
                final phase = PhaseRegistry.phases[index];
                final isPhaseExpanded = navState.expandedPhases.contains(phase.id);

                return Column(
                  children: [
                    // Level 1: Phase
                    _TreeHeaderNode(
                      label: phase.name,
                      icon: phase.icon,
                      isExpanded: isPhaseExpanded,
                      indent: 16.0,
                      onTap: () => notifier.togglePhaseExpanded(phase.id),
                    ),
                    // Level 2: Modules (if phase is expanded)
                    if (isPhaseExpanded)
                      ...phase.modules.map((module) {
                        final isModuleExpanded = navState.expandedModules.contains(module.id);
                        return Column(
                          children: [
                            _TreeHeaderNode(
                              label: module.name,
                              icon: module.icon,
                              isExpanded: isModuleExpanded,
                              indent: 32.0,
                              onTap: () => notifier.toggleModuleExpanded(module.id),
                            ),
                            // Level 3: Actions (if module is expanded)
                            if (isModuleExpanded)
                              ...module.actions.map((action) {
                                final isSelected = navState.selectedActionId == action.id;
                                return _TreeLeafNode(
                                  label: action.name,
                                  icon: action.icon,
                                  isSelected: isSelected,
                                  indent: 48.0,
                                  onTap: () {
                                    notifier.selectAction(phase.id, module.id, action.id);
                                  },
                                );
                              }),
                          ],
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeHeaderNode extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isExpanded;
  final double indent;
  final VoidCallback onTap;

  const _TreeHeaderNode({
    required this.label,
    required this.icon,
    required this.isExpanded,
    required this.indent,
    required this.onTap,
  });

  @override
  State<_TreeHeaderNode> createState() => _TreeHeaderNodeState();
}

class _TreeHeaderNodeState extends State<_TreeHeaderNode> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.only(left: widget.indent, right: 16, top: 8, bottom: 8),
          color: _hover ? MidnightHacker.primary.withOpacity(0.05) : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                color: _hover ? MidnightHacker.primary : MidnightHacker.dimGreen,
                size: 18,
              ),
              const SizedBox(width: 4),
              Icon(
                widget.icon,
                color: widget.isExpanded ? MidnightHacker.primary : MidnightHacker.dimGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: MidnightHacker.monoSmall.copyWith(
                    color: widget.isExpanded ? MidnightHacker.primary : MidnightHacker.dimGreen,
                    fontWeight: widget.isExpanded ? FontWeight.bold : FontWeight.normal,
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

class _TreeLeafNode extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final double indent;
  final VoidCallback onTap;

  const _TreeLeafNode({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.indent,
    required this.onTap,
  });

  @override
  State<_TreeLeafNode> createState() => _TreeLeafNodeState();
}

class _TreeLeafNodeState extends State<_TreeLeafNode> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.only(left: widget.indent, right: 16, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: widget.isSelected ? MidnightHacker.primary.withOpacity(0.1) : (_hover ? MidnightHacker.primary.withOpacity(0.05) : Colors.transparent),
            border: Border(
              left: widget.isSelected
                  ? MidnightHacker.greenBorderThick
                  : const BorderSide(color: Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected ? MidnightHacker.positive : MidnightHacker.dimGreen,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: MidnightHacker.monoSmall.copyWith(
                    color: widget.isSelected ? MidnightHacker.positive : MidnightHacker.dimGreen,
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

class _CollapsedIconItem extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _CollapsedIconItem({
    required this.icon,
    required this.tooltip,
    this.active = false,
    required this.onTap,
  });

  @override
  State<_CollapsedIconItem> createState() => _CollapsedIconItemState();
}

class _CollapsedIconItemState extends State<_CollapsedIconItem> {
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
            height: 50,
            decoration: BoxDecoration(
              border: Border(
                left: widget.active
                    ? MidnightHacker.greenBorderThick
                    : const BorderSide(color: Colors.transparent, width: 2),
              ),
            ),
            child: Icon(
              widget.icon,
              color: widget.active
                  ? MidnightHacker.positive
                  : (_hover ? MidnightHacker.primary : MidnightHacker.dimGreen),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedNavOption extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ExpandedNavOption({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_ExpandedNavOption> createState() => _ExpandedNavOptionState();
}

class _ExpandedNavOptionState extends State<_ExpandedNavOption> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              left: widget.active
                  ? MidnightHacker.greenBorderThick
                  : const BorderSide(color: Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.active ? MidnightHacker.positive : MidnightHacker.primary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: MidnightHacker.monoSmall.copyWith(
                    color: widget.active ? MidnightHacker.primary : (_hover ? MidnightHacker.primary : MidnightHacker.dimGreen),
                    fontWeight: widget.active ? FontWeight.bold : FontWeight.normal,
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
