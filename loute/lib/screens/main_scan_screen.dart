import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/midnight_hacker.dart';
import '../providers/navigation_state.dart';
import '../components/navbar.dart';
import '../components/side_panel.dart';
import 'dashboard_screen.dart';
import 'documentation_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import '../features/cap/capability_screen.dart';
import '../features/cap/capability_explorer_screen.dart';
import '../features/ops/ops_dashboard_screen.dart';
import '../features/providers/provider_health_screen.dart';
import '../features/jobs/jobs_screen.dart';
import '../features/findings/findings_screen.dart';
import '../features/graph/asset_graph_screen.dart';
import '../features/ws/workspaces_screen.dart';
import '../features/vault/credential_vault_screen.dart';
import '../features/payloads/payload_studio_screen.dart';
import '../features/timeline/timeline_screen.dart';

/// Coordinates the header, the sidebar and the active workspace.
class MainScanScreen extends ConsumerWidget {
  const MainScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);

    return Scaffold(
      backgroundColor: MidnightHacker.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 300 || constraints.maxHeight < 200) {
            return Container(color: MidnightHacker.background);
          }
          final scale = (constraints.maxWidth / 1280.0).clamp(0.75, 1.25);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: Column(
              children: [
                const Navbar(),
                Expanded(
                  child: Row(
                    children: [
                      const SidePanel(),
                      Expanded(child: _contentFor(navState.activeScreen)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _contentFor(ActiveScreen screen) {
    switch (screen) {
      case ActiveScreen.capability:
        return const CapabilityScreen();
      case ActiveScreen.toolManager:
      case ActiveScreen.capabilities:
        return const ToolManagerScreen();
      case ActiveScreen.documentation:
        return const DocumentationScreen();
      case ActiveScreen.settings:
        return const SettingsScreen();
      case ActiveScreen.reports:
        return const ReportsScreen();
      case ActiveScreen.ops:
        return const OpsDashboardScreen();
      case ActiveScreen.providers:
        return const ProviderHealthScreen();
      case ActiveScreen.jobs:
        return const JobsScreen();
      case ActiveScreen.findings:
        return const FindingsScreen();
      case ActiveScreen.graph:
        return const AssetGraphScreen();
      case ActiveScreen.workspaces:
        return const WorkspacesScreen();
      case ActiveScreen.vault:
        return const CredentialVaultScreen();
      case ActiveScreen.payloads:
        return const PayloadStudioScreen();
      case ActiveScreen.timeline:
        return const TimelineScreen();
      case ActiveScreen.dashboard:
      default:
        return const DashboardScreen();
    }
  }
}
