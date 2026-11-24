import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/midnight_hacker.dart';
import '../models/phase_registry.dart';
import '../models/phase_model.dart';
import '../providers/navigation_state.dart';
import '../components/navbar.dart';
import '../components/side_panel.dart';
import '../components/action_card.dart';
import 'dashboard_screen.dart';
import 'documentation_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import '../features/ops/ops_dashboard_screen.dart';
import '../features/cap/capability_explorer_screen.dart';
import '../features/providers/provider_health_screen.dart';
import '../features/jobs/jobs_screen.dart';
import '../features/findings/findings_screen.dart';
import '../features/graph/asset_graph_screen.dart';
import '../features/ws/workspaces_screen.dart';
import '../features/vault/credential_vault_screen.dart';
import '../features/payloads/payload_studio_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/arena/arena_screen.dart';

/// Main scan screen - coordinates main layout, sidebar/bottom nav modes, and content switching.
class MainScanScreen extends ConsumerWidget {
  const MainScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    // Determine what content to show in the main central area
    Widget mainContent;
    String? phaseName;
    String? moduleName;

    final action = navState.currentAction;
    if (navState.activeScreen == ActiveScreen.action && action != null) {
      for (final phase in PhaseRegistry.phases) {
        for (final module in phase.modules) {
          if (module.actions.any((a) => a.id == action.id)) {
            phaseName = phase.name;
            moduleName = module.name;
            break;
          }
        }
        if (phaseName != null) break;
      }
      mainContent = ActionCard(
        action: action,
        moduleName: moduleName ?? '',
        phaseName: phaseName ?? '',
      );
    } else if (navState.activeScreen == ActiveScreen.documentation) {
      mainContent = const DocumentationScreen();
    } else if (navState.activeScreen == ActiveScreen.settings) {
      mainContent = const SettingsScreen();
    } else if (navState.activeScreen == ActiveScreen.reports) {
      mainContent = const ReportsScreen();
    } else if (navState.activeScreen == ActiveScreen.ops) {
      mainContent = const OpsDashboardScreen();
    } else if (navState.activeScreen == ActiveScreen.capabilities) {
      mainContent = const CapabilityExplorerScreen();
    } else if (navState.activeScreen == ActiveScreen.providers) {
      mainContent = const ProviderHealthScreen();
    } else if (navState.activeScreen == ActiveScreen.jobs) {
      mainContent = const JobsScreen();
    } else if (navState.activeScreen == ActiveScreen.findings) {
      mainContent = const FindingsScreen();
    } else if (navState.activeScreen == ActiveScreen.graph) {
      mainContent = const AssetGraphScreen();
    } else if (navState.activeScreen == ActiveScreen.workspaces) {
      mainContent = const WorkspacesScreen();
    } else if (navState.activeScreen == ActiveScreen.vault) {
      mainContent = const CredentialVaultScreen();
    } else if (navState.activeScreen == ActiveScreen.payloads) {
      mainContent = const PayloadStudioScreen();
    } else if (navState.activeScreen == ActiveScreen.timeline) {
      mainContent = const TimelineScreen();
    } else if (navState.activeScreen == ActiveScreen.arena) {
      mainContent = const ArenaScreen();
    } else {
      mainContent = const DashboardScreen();
    }

    final showSidebar =
        navState.navBarPreference == 'side'; // never hide side panel completely
    final showBottomNav = navState.navBarPreference == 'bottom';

    return Scaffold(
      backgroundColor: MidnightHacker.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Prevent layout calculations during the transient boot/resize/VM initialization frames
          if (constraints.maxWidth < 300 || constraints.maxHeight < 200) {
            return Container(
              color: MidnightHacker.background,
              child: const Center(
                child: SizedBox.shrink(),
              ),
            );
          }

          // Calculate a responsive scaling factor based on width
          // Assume base width of 1280. We clamp to prevent extreme tiny text.
          final scaleFactor = (constraints.maxWidth / 1280.0).clamp(0.75, 1.25);

          return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scaleFactor),
              ),
              child: Column(
                children: [
                  // ── Header Navbar ──
                  const Navbar(),

                  // ── Body Layout ──
                  Expanded(
                    child: Row(
                      children: [
                        // Left Side Panel
                        if (showSidebar) const SidePanel(),

                        // Central Workspace Area
                        Expanded(
                          child: mainContent,
                        ),
                      ],
                    ),
                  ),

                  // ── Bottom Nav ──
                  if (showBottomNav) const _HoverBottomNavBar(),
                ],
              ));
        },
      ),
    );
  }
}

/// Permanently visible bottom navigation bar with popup overlays.
class _HoverBottomNavBar extends ConsumerStatefulWidget {
  const _HoverBottomNavBar();

  @override
  ConsumerState<_HoverBottomNavBar> createState() => _HoverBottomNavBarState();
}

class _HoverBottomNavBarState extends ConsumerState<_HoverBottomNavBar> {
  OverlayEntry? _popupOverlay;
  String? _hoveredPhaseId;
  String? _hoveredModuleId;
  bool _isPopupHovered = false;

  final Map<String, GlobalKey> _phaseKeys = {};

  @override
  void initState() {
    super.initState();
    for (var phase in PhaseRegistry.phases) {
      _phaseKeys[phase.id] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _removePopup();
    super.dispose();
  }

  void _removePopup() {
    _popupOverlay?.remove();
    _popupOverlay = null;
    _hoveredPhaseId = null;
    _hoveredModuleId = null;
    _isPopupHovered = false;
  }

  void _showPopup(BuildContext context, Phase phase, GlobalKey key) {
    if (_hoveredPhaseId == phase.id) return; // Already showing this one

    _removePopup();
    _hoveredPhaseId = phase.id;
    _hoveredModuleId = null;

    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // The maximum width of the cascading popup is 320 (160 for modules + 160 for actions)
    double popupWidth = 320;

    double clampedDx = offset.dx;
    if (clampedDx + popupWidth > screenWidth) {
      clampedDx = screenWidth - popupWidth - 8; // 8px padding from right edge
    }
    if (clampedDx < 8) {
      clampedDx = 8; // 8px padding from left edge
    }

    _popupOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: clampedDx,
          bottom: 56.0 + 8.0, // Above the bottom nav (56px) + small gap
          child: Material(
            color: Colors.transparent,
            child: MouseRegion(
              onEnter: (_) {
                _isPopupHovered = true;
              },
              onExit: (_) {
                _isPopupHovered = false;
                _checkClosePopup();
              },
              child: _CascadingPopupContent(
                phase: phase,
                initialModuleId: _hoveredModuleId,
                maxHeight: screenHeight - 80, // Prevent vertical overflow
                onModuleHover: (moduleId) {
                  setState(() {
                    _hoveredModuleId = moduleId;
                  });
                  _popupOverlay?.markNeedsBuild();
                },
                onActionSelect: (moduleId, actionId) {
                  ref
                      .read(navigationProvider.notifier)
                      .selectAction(phase.id, moduleId, actionId);
                  _removePopup();
                },
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_popupOverlay!);
  }

  void _checkClosePopup() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (!_isPopupHovered && _hoveredPhaseId == null) {
        _removePopup();
      }
    });
  }

  void _onPhaseIconExit() {
    final oldPhaseId = _hoveredPhaseId;
    _hoveredPhaseId = null;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (!_isPopupHovered && _hoveredPhaseId == null && oldPhaseId != null) {
        _removePopup();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final notifier = ref.read(navigationProvider.notifier);

    final phaseIcons = [
      Icons.radar_outlined,
      Icons.search_outlined,
      Icons.lock_open_outlined,
      Icons.security_outlined,
      Icons.settings_suggest_outlined,
      Icons.lan_outlined,
      Icons.description_outlined,
      Icons.terminal_outlined,
      Icons.api_outlined,
      Icons.assignment_outlined,
    ];

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: MidnightHacker.panelBg,
        border: Border(top: MidnightHacker.greenBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 4 Main Icons
          _BottomNavItem(
            icon: Icons.dashboard_outlined,
            tooltip: 'Dashboard',
            active: navState.activeScreen == ActiveScreen.dashboard,
            onTap: () => notifier.setActiveScreen(ActiveScreen.dashboard),
          ),
          _BottomNavItem(
            icon: Icons.menu_book_outlined,
            tooltip: 'Documentation',
            active: navState.activeScreen == ActiveScreen.documentation,
            onTap: () => notifier.setActiveScreen(ActiveScreen.documentation),
          ),
          _BottomNavItem(
            icon: Icons.assessment_outlined,
            tooltip: 'Reports',
            active: navState.activeScreen == ActiveScreen.reports,
            onTap: () => notifier.setActiveScreen(ActiveScreen.reports),
          ),
          _BottomNavItem(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            active: navState.activeScreen == ActiveScreen.settings,
            onTap: () => notifier.setActiveScreen(ActiveScreen.settings),
          ),

          // Divider
          Container(width: 1, height: 24, color: MidnightHacker.dimGreen),

          // 10 Phase Icons
          ...List.generate(PhaseRegistry.phases.length, (index) {
            final phase = PhaseRegistry.phases[index];
            final active = navState.selectedPhaseId == phase.id;
            final key = _phaseKeys[phase.id]!;

            return MouseRegion(
              key: key,
              onEnter: (_) => _showPopup(context, phase, key),
              onExit: (_) => _onPhaseIconExit(),
              child: _BottomNavItem(
                icon: phase.icon,
                tooltip: '', // Disable default tooltip, popup handles it
                active: active,
                onTap: () => _showPopup(context, phase, key),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    Widget child = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: widget.active
                  ? MidnightHacker.greenBorderThick
                  : const BorderSide(color: Colors.transparent, width: 2),
            ),
          ),
          child: Icon(
            widget.icon,
            color: widget.active
                ? MidnightHacker.positive
                : (_hover ? MidnightHacker.primary : MidnightHacker.dimGreen),
            size: 24,
          ),
        ),
      ),
    );

    if (widget.tooltip.isEmpty) {
      return child;
    }

    return Tooltip(
      message: widget.tooltip,
      child: child,
    );
  }
}

/// The Cascading Popup that shows Modules, and if hovered, Actions.
class _CascadingPopupContent extends StatelessWidget {
  final Phase phase;
  final String? initialModuleId;
  final double maxHeight;
  final Function(String) onModuleHover;
  final Function(String, String) onActionSelect;

  const _CascadingPopupContent({
    required this.phase,
    this.initialModuleId,
    required this.maxHeight,
    required this.onModuleHover,
    required this.onActionSelect,
  });

  @override
  Widget build(BuildContext context) {
    Module? activeModule;
    if (initialModuleId != null) {
      try {
        activeModule = phase.modules.firstWhere((m) => m.id == initialModuleId);
      } catch (_) {}
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: MidnightHacker.panelBg,
        border: Border.all(color: MidnightHacker.primary, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modules Column
            SizedBox(
              width: 160,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                          border: Border(bottom: MidnightHacker.greenBorder)),
                      child: Text(
                        phase.name.toUpperCase(),
                        style: MidnightHacker.monoSmall.copyWith(
                            color: MidnightHacker.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...phase.modules.map((m) {
                      final isHovered = m.id == initialModuleId;
                      return MouseRegion(
                        onEnter: (_) => onModuleHover(m.id),
                        child: GestureDetector(
                          onTap: () => onModuleHover(m.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            color: isHovered
                                ? MidnightHacker.primary.withOpacity(0.1)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Icon(m.icon,
                                    color: MidnightHacker.dimGreen, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    m.name,
                                    style: MidnightHacker.monoSmall.copyWith(
                                        color: isHovered
                                            ? MidnightHacker.primary
                                            : MidnightHacker.dimGreen),
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_right,
                                    color: isHovered
                                        ? MidnightHacker.primary
                                        : MidnightHacker.dimGreen,
                                    size: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Right Column: Actions (only if a module is hovered)
            if (activeModule != null)
              Container(
                width: 160,
                decoration: const BoxDecoration(
                  border: Border(left: MidnightHacker.greenBorder),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            border: Border(bottom: MidnightHacker.greenBorder)),
                        child: Text(
                          'ACTIONS',
                          style: MidnightHacker.monoSmall
                              .copyWith(color: MidnightHacker.dimGreen),
                        ),
                      ),
                      ...activeModule.actions.map((a) {
                        return _ActionHoverItem(
                          action: a,
                          onTap: () => onActionSelect(activeModule!.id, a.id),
                        );
                      }),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionHoverItem extends StatefulWidget {
  final ActionItem action;
  final VoidCallback onTap;

  const _ActionHoverItem({required this.action, required this.onTap});

  @override
  State<_ActionHoverItem> createState() => _ActionHoverItemState();
}

class _ActionHoverItemState extends State<_ActionHoverItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: _hover
              ? MidnightHacker.primary.withOpacity(0.1)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(widget.action.icon,
                  color: _hover
                      ? MidnightHacker.positive
                      : MidnightHacker.dimGreen,
                  size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.action.name,
                  style: MidnightHacker.monoSmall.copyWith(
                    color: _hover
                        ? MidnightHacker.positive
                        : MidnightHacker.dimGreen,
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
