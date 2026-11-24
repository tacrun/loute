import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import '../themes/midnight_hacker.dart';
import '../providers/navigation_state.dart';
import '../providers/settings_state.dart';

/// Top navbar - hamburger toggle, LOUTE logo image, screen selector, and window controls.
class Navbar extends ConsumerWidget implements PreferredSizeWidget {
  const Navbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  Future<void> _toggleFullscreen() async {
    try {
      bool isFull = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFull);
    } catch (_) {
      // Graceful fallback
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: MidnightHacker.background,
        border: Border(bottom: MidnightHacker.greenBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Hamburger toggle (only if Side Nav is active)
          if (navState.navBarPreference == 'side')
            _NavIcon(
              icon: Icons.menu_outlined,
              tooltip: 'Toggle Side Panel',
              onTap: () => ref
                  .read(navigationProvider.notifier)
                  .toggleSidePanelCollapsed(),
            ),
          if (navState.navBarPreference == 'side') const SizedBox(width: 12),

          // Logo Image in perfect usable dimension (28x28)
          Image.asset(
            'assets/icons/logo.png',
            height: 28,
            width: 28,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),

          // Title
          Tooltip(
            message: 'View System Identity',
            textStyle: MidnightHacker.monoSmall
                .copyWith(color: MidnightHacker.primary),
            decoration: BoxDecoration(
                color: MidnightHacker.panelBg,
                border: Border.all(color: MidnightHacker.primary)),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showSystemIdentityDialog(context, ref),
                child: Row(
                  children: [
                    Text(
                      'LOUTE',
                      style: MidnightHacker.heading.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'V1.5.5',
                      style: MidnightHacker.labelDim.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // Centered Host Environment Indicator
          Tooltip(
            message: 'View Architecture Details',
            textStyle: MidnightHacker.monoSmall
                .copyWith(color: MidnightHacker.primary),
            decoration: BoxDecoration(
                color: MidnightHacker.panelBg,
                border: Border.all(color: MidnightHacker.primary)),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showArchitectureDialog(context),
                child: Icon(
                  Platform.isLinux
                      ? Icons.terminal_outlined
                      : Platform.isWindows
                          ? Icons.desktop_windows_outlined
                          : Platform.isAndroid
                              ? Icons.phone_android_outlined
                              : Icons.computer_outlined,
                  color: MidnightHacker.primary,
                  size: 20,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Shortcut Icons: Ops Dashboard, Capabilities, Jobs, Findings, Graph, Docs, Reports, Settings
          _NavIcon(
            icon: Icons.dashboard_outlined,
            tooltip: 'Dashboard',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.dashboard),
          ),
          _NavIcon(
            icon: Icons.flash_on_outlined,
            tooltip: 'Capabilities',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.capabilities),
          ),
          _NavIcon(
            icon: Icons.dns_outlined,
            tooltip: 'Providers',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.providers),
          ),
          _NavIcon(
            icon: Icons.play_arrow_outlined,
            tooltip: 'Jobs',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.jobs),
          ),
          _NavIcon(
            icon: Icons.bug_report_outlined,
            tooltip: 'Findings',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.findings),
          ),
          _NavIcon(
            icon: Icons.account_tree_outlined,
            tooltip: 'Graph',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.graph),
          ),
          _NavIcon(
            icon: Icons.folder_outlined,
            tooltip: 'Workspaces',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.workspaces),
          ),
          _NavIcon(
            icon: Icons.key_outlined,
            tooltip: 'Credential Vault',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.vault),
          ),
          _NavIcon(
            icon: Icons.construction_outlined,
            tooltip: 'Payload Studio',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.payloads),
          ),
          _NavIcon(
            icon: Icons.timeline_outlined,
            tooltip: 'Campaign Timeline',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.timeline),
          ),
          _NavIcon(
            icon: Icons.emoji_events_outlined,
            tooltip: 'CTF Arena',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.arena),
          ),
          _NavIcon(
            icon: Icons.menu_book_outlined,
            tooltip: 'Documentation',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.documentation),
          ),
          _NavIcon(
            icon: Icons.assessment_outlined,
            tooltip: 'Reports',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.reports),
          ),
          _NavIcon(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setActiveScreen(ActiveScreen.settings),
          ),

          const SizedBox(width: 12),
          // Vertical divider separating screen options and window controls
          Container(
            height: 24,
            width: 1,
            color: MidnightHacker.primary,
          ),
          const SizedBox(width: 12),

          // Window Controls: Fullscreen Toggle and Exit Application
          _NavIcon(
            icon: Icons.fullscreen_outlined,
            tooltip: 'Toggle Fullscreen (F11)',
            onTap: _toggleFullscreen,
          ),
          _NavIcon(
            icon: Icons.close_outlined,
            tooltip: 'Close Application',
            onTap: () => exit(0),
          ),
        ],
      ),
    );
  }

  void _showSystemIdentityDialog(BuildContext context, WidgetRef ref) {
    final navState = ref.read(navigationProvider);

    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: MidnightHacker.panelBg,
              border: Border.all(color: MidnightHacker.primary, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/icons/logo.png', height: 80, width: 80),
                const SizedBox(height: 16),
                Text('LOUTE',
                    style: MidnightHacker.headingLarge
                        .copyWith(fontSize: 32, letterSpacing: 4)),
                const SizedBox(height: 6),
                Text('v${navState.systemVersion}',
                    style: MidnightHacker.monoStyle.copyWith(
                        color: MidnightHacker.dimGreen, fontSize: 12)),
                const SizedBox(height: 12),
                Divider(color: MidnightHacker.dimGreen.withOpacity(0.4)),
                const SizedBox(height: 12),

                // Author
                Text('funbinet',
                    style: MidnightHacker.heading
                        .copyWith(color: MidnightHacker.primary, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Security Engineer',
                    style: MidnightHacker.monoSmall
                        .copyWith(color: MidnightHacker.dimGreen)),
                const SizedBox(height: 16),

                // Social Icons Row - Real brand icons, clickable
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildClickableSocial(FontAwesomeIcons.github, 'GitHub',
                        'https://github.com/funbinet'),
                    const SizedBox(width: 14),
                    _buildClickableSocial(FontAwesomeIcons.gitlab, 'GitLab',
                        'https://gitlab.com/funbinet'),
                    const SizedBox(width: 14),
                    _buildClickableSocial(FontAwesomeIcons.codepen, 'Codeberg',
                        'https://codeberg.org/funbinet'),
                    const SizedBox(width: 14),
                    _buildClickableSocial(FontAwesomeIcons.envelope, 'Email',
                        'mailto:funbinet@gmail.com'),
                    const SizedBox(width: 14),
                    _buildClickableSocial(FontAwesomeIcons.globe, 'Website',
                        'http://funbinet.dev'),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: MidnightHacker.dimGreen.withOpacity(0.4)),
                const SizedBox(height: 12),

                // System Description
                Text(
                  'LOUTE is an autonomous bug bounty and security reconnaissance framework. '
                  'It orchestrates multi-phase penetration testing workflows - from passive '
                  'reconnaissance through active exploitation - powered by a native Rust engine '
                  'and a zero-dependency Flutter command interface.',
                  style: MidnightHacker.monoSmall
                      .copyWith(color: MidnightHacker.dimGreen, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClickableSocial(dynamic icon, String tooltip, String url) {
    return Tooltip(
      message: tooltip,
      textStyle:
          MidnightHacker.monoSmall.copyWith(color: MidnightHacker.primary),
      decoration: BoxDecoration(
          color: MidnightHacker.panelBg,
          border: Border.all(color: MidnightHacker.primary)),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(url)),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MidnightHacker.background,
              border: Border.all(color: MidnightHacker.dimGreen, width: 1),
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, color: MidnightHacker.dimGreen, size: 18),
          ),
        ),
      ),
    );
  }

  void _showArchitectureDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _EnvironmentDialog(),
    );
  }
}

/// Stateful dialog that fetches live system + network data on mount.
class _EnvironmentDialog extends StatefulWidget {
  const _EnvironmentDialog();
  @override
  State<_EnvironmentDialog> createState() => _EnvironmentDialogState();
}

class _EnvironmentDialogState extends State<_EnvironmentDialog> {
  bool _loading = true;
  String _publicIp = '-';
  String _isp = '-';
  String _city = '-';
  String _region = '-';
  String _country = '-';
  String _lat = '-';
  String _lon = '-';
  String _timezone = '-';
  String _privateIp = '-';

  @override
  void initState() {
    super.initState();
    _fetchNetworkInfo();
  }

  Future<void> _fetchNetworkInfo() async {
    // Private IP
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            _privateIp = addr.address;
            break;
          }
        }
        if (_privateIp != '-') break;
      }
    } catch (_) {}

    // Public IP + Geolocation via ip-api.com (free, no key)
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _publicIp = data['query'] ?? '-';
        _isp = data['isp'] ?? '-';
        _city = data['city'] ?? '-';
        _region = data['regionName'] ?? '-';
        _country = data['country'] ?? '-';
        _lat = (data['lat'] ?? '-').toString();
        _lon = (data['lon'] ?? '-').toString();
        _timezone = data['timezone'] ?? '-';
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: MidnightHacker.monoSmall
                      .copyWith(color: MidnightHacker.dimGreen))),
          Expanded(
              child: Text(value,
                  style: MidnightHacker.monoSmall.copyWith(
                      color: MidnightHacker.primary,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: MidnightHacker.panelBg,
            border: Border.all(color: MidnightHacker.primary, width: 1),
          ),
          child: _loading
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                            color: MidnightHacker.primary, strokeWidth: 2)),
                    const SizedBox(height: 16),
                    Text('Resolving host environment...',
                        style: MidnightHacker.monoSmall
                            .copyWith(color: MidnightHacker.dimGreen)),
                    const SizedBox(height: 24),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Platform.isLinux
                            ? Icons.terminal_outlined
                            : Icons.computer_outlined,
                        color: MidnightHacker.primary,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text('HOST ENVIRONMENT',
                          style: MidnightHacker.heading.copyWith(
                              color: MidnightHacker.primary,
                              letterSpacing: 2,
                              fontSize: 16)),
                      const SizedBox(height: 12),
                      Divider(color: MidnightHacker.dimGreen.withOpacity(0.4)),

                      // System Section
                      const SizedBox(height: 8),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Text('SYSTEM',
                              style: MidnightHacker.monoSmall.copyWith(
                                  color: MidnightHacker.primary,
                                  fontSize: 10,
                                  letterSpacing: 2))),
                      const SizedBox(height: 6),
                      _row('OS / Platform',
                          Platform.operatingSystem.toUpperCase()),
                      _row('OS Version', Platform.operatingSystemVersion),
                      _row('Architecture', 'x86_64'),
                      _row(
                          'Processors', Platform.numberOfProcessors.toString()),
                      _row('Locale', Platform.localeName),
                      _row('Executable', Platform.resolvedExecutable),

                      const SizedBox(height: 12),
                      Divider(color: MidnightHacker.dimGreen.withOpacity(0.4)),

                      // Engine Section
                      const SizedBox(height: 8),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Text('ENGINE',
                              style: MidnightHacker.monoSmall.copyWith(
                                  color: MidnightHacker.primary,
                                  fontSize: 10,
                                  letterSpacing: 2))),
                      const SizedBox(height: 6),
                      _row('Backend', 'Native Rust / Tokio'),
                      _row('GUI Renderer',
                          'Flutter / ${Platform.isLinux ? "Wayland" : "Native"}'),
                      _row('Dart Version', Platform.version.split(' ').first),

                      const SizedBox(height: 12),
                      Divider(color: MidnightHacker.dimGreen.withOpacity(0.4)),

                      // Network Section
                      const SizedBox(height: 8),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Text('NETWORK',
                              style: MidnightHacker.monoSmall.copyWith(
                                  color: MidnightHacker.primary,
                                  fontSize: 10,
                                  letterSpacing: 2))),
                      const SizedBox(height: 6),
                      _row('Private IP', _privateIp),
                      _row('Public IP', _publicIp),
                      _row('ISP', _isp),

                      const SizedBox(height: 12),
                      Divider(color: MidnightHacker.dimGreen.withOpacity(0.4)),

                      // Location Section
                      const SizedBox(height: 8),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Text('GEOLOCATION',
                              style: MidnightHacker.monoSmall.copyWith(
                                  color: MidnightHacker.primary,
                                  fontSize: 10,
                                  letterSpacing: 2))),
                      const SizedBox(height: 6),
                      _row('City', _city),
                      _row('Region', _region),
                      _row('Country', _country),
                      _row('Latitude', _lat),
                      _row('Longitude', _lon),
                      _row('Timezone', _timezone),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _NavIcon(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<_NavIcon> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              border: _hovering
                  ? Border.all(color: MidnightHacker.primary, width: 1)
                  : Border.all(color: Colors.transparent, width: 1),
            ),
            child: Icon(widget.icon, color: MidnightHacker.primary, size: 20),
          ),
        ),
      ),
    );
  }
}
