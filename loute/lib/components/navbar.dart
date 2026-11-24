import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;
import '../themes/midnight_hacker.dart';
import '../providers/navigation_state.dart';

/// Top header. Navigation lives in the sidebar; this bar only carries the
/// centered system name and utility controls.
class Navbar extends ConsumerWidget implements PreferredSizeWidget {
  const Navbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(52);

  Future<void> _toggleFullscreen() async {
    try {
      final isFull = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFull);
    } catch (_) {
      // Graceful fallback on platforms without window management.
    }
  }

  void _showIdentity(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MidnightHacker.panelBg,
              border: Border.all(color: MidnightHacker.primary),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/icons/logo.png', height: 64, width: 64),
                const SizedBox(height: 12),
                Text('LOUTE',
                    style: MidnightHacker.headingLarge.copyWith(fontSize: 28, letterSpacing: 4)),
                const SizedBox(height: 6),
                Text('Autonomous Bug Bounty Framework',
                    style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen)),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'LOUTE orchestrates catalog driven reconnaissance and exploitation '
                  'workflows through a native Rust engine. Choose a phase and a '
                  'capability in the sidebar, then select an action and execute it.',
                  style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTerminal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _EnvironmentDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(navigationProvider.notifier);

    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: MidnightHacker.background,
        border: Border(bottom: MidnightHacker.greenBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const Spacer(),
          GestureDetector(
            onTap: () => _showIdentity(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/icons/logo.png', height: 24, width: 24),
                const SizedBox(width: 10),
                Text(
                  'LOUTE',
                  style: MidnightHacker.heading.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _HeaderIcon(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => notifier.setActiveScreen(ActiveScreen.settings),
          ),
          _HeaderIcon(
            icon: Icons.assessment_outlined,
            tooltip: 'Reports',
            onTap: () => notifier.setActiveScreen(ActiveScreen.reports),
          ),
          _HeaderIcon(
            icon: Icons.menu_book_outlined,
            tooltip: 'Documentation',
            onTap: () => notifier.setActiveScreen(ActiveScreen.documentation),
          ),
          _HeaderIcon(
            icon: Icons.terminal_outlined,
            tooltip: 'Host Environment',
            onTap: () => _showTerminal(context),
          ),
          Container(height: 22, width: 1, color: MidnightHacker.dimGreen),
          _HeaderIcon(
            icon: Icons.fullscreen_outlined,
            tooltip: 'Toggle Fullscreen',
            onTap: _toggleFullscreen,
          ),
          _HeaderIcon(
            icon: Icons.close_outlined,
            tooltip: 'Close Application',
            onTap: () => exit(0),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_HeaderIcon> createState() => _HeaderIconState();
}

class _HeaderIconState extends State<_HeaderIcon> {
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
            width: 38,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              border: Border.all(
                color: _hover ? MidnightHacker.primary : Colors.transparent,
              ),
            ),
            child: Icon(
              widget.icon,
              color: _hover ? MidnightHacker.positive : MidnightHacker.primary,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}

/// Live host environment readout opened by the terminal icon.
class _EnvironmentDialog extends StatefulWidget {
  const _EnvironmentDialog();

  @override
  State<_EnvironmentDialog> createState() => _EnvironmentDialogState();
}

class _EnvironmentDialogState extends State<_EnvironmentDialog> {
  bool _loading = true;
  String _publicIp = '-';
  String _isp = '-';
  String _privateIp = '-';
  String _city = '-';
  String _country = '-';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
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

    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _publicIp = data['query'] ?? '-';
        _isp = data['isp'] ?? '-';
        _city = data['city'] ?? '-';
        _country = data['country'] ?? '-';
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 130, child: Text(label, style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen))),
            Expanded(child: Text(value, style: MidnightHacker.monoSmall)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: MidnightHacker.panelBg,
            border: Border.all(color: MidnightHacker.primary),
          ),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: MidnightHacker.primary),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.terminal_outlined, color: MidnightHacker.primary, size: 40),
                      const SizedBox(height: 8),
                      Text('HOST ENVIRONMENT', style: MidnightHacker.heading.copyWith(letterSpacing: 2)),
                      const SizedBox(height: 12),
                      const Divider(),
                      _row('Platform', Platform.operatingSystem.toUpperCase()),
                      _row('Version', Platform.operatingSystemVersion),
                      _row('Architecture', Platform.numberOfProcessors.toString() + ' cores'),
                      _row('Private IP', _privateIp),
                      _row('Public IP', _publicIp),
                      _row('ISP', _isp),
                      _row('City', _city),
                      _row('Country', _country),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
