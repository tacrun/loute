// capability_explorer_screen.dart - OS-aware tool manager for the catalog.
// Browsing follows phase > capability > action > sub-action, and every
// sub-action lists the provider tools it needs with install controls.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../themes/midnight_hacker.dart';
import '../../models/catalog_ui.dart';
import '../../generated/capability_index.dart';
import '../../components/progress_bar.dart';

enum HostFamily { arch, debian, windows, android, linux, unknown }

class ToolRecord {
  final String binary;
  final String package;
  bool installed;
  bool installing;
  bool failed;
  String note;

  ToolRecord({
    required this.binary,
    required this.package,
    this.installed = false,
    this.installing = false,
    this.failed = false,
    this.note = '',
  });
}

class ToolManagerScreen extends ConsumerStatefulWidget {
  const ToolManagerScreen({super.key});

  @override
  ConsumerState<ToolManagerScreen> createState() => _ToolManagerScreenState();
}

class _ToolManagerScreenState extends ConsumerState<ToolManagerScreen> {
  HostFamily _family = HostFamily.unknown;
  String _osLabel = 'DETECTING';
  String _packageManager = '-';
  bool _detected = false;

  String? _phaseId;
  String? _capabilityId;
  String? _groupId;
  int _operationIndex = 0;

  final Map<String, ToolRecord> _tools = {};
  final Set<String> _checking = {};

  @override
  void initState() {
    super.initState();
    _detectHost();
  }

  Future<void> _detectHost() async {
    HostFamily family = HostFamily.unknown;
    String label = Platform.operatingSystem.toUpperCase();
    String manager = '-';

    if (Platform.isWindows) {
      family = HostFamily.windows;
      manager = 'winget';
      label = 'WINDOWS';
    } else if (Platform.isAndroid) {
      family = HostFamily.android;
      manager = 'pkg';
      label = 'ANDROID / TERMUX';
    } else if (Platform.isLinux) {
      try {
        final file = File('/etc/os-release');
        if (await file.exists()) {
          final content = await file.readAsString();
          final id = RegExp(r'^ID="?([^"\n]+)"?', multiLine: true)
                  .firstMatch(content)
                  ?.group(1)
                  ?.toLowerCase() ??
              '';
          final pretty = RegExp(r'^PRETTY_NAME="?([^"\n]+)"?', multiLine: true)
                  .firstMatch(content)
                  ?.group(1) ??
              'Linux';
          label = pretty.toUpperCase();
          if (['arch', 'manjaro', 'artix', 'endeavouros'].contains(id)) {
            family = HostFamily.arch;
            manager = 'pacman -S --needed';
          } else if ([
            'debian',
            'ubuntu',
            'kali',
            'linuxmint',
            'pop',
            'parrot',
            'raspbian'
          ].contains(id)) {
            family = HostFamily.debian;
            manager = 'apt-get install -y';
          } else {
            family = HostFamily.linux;
            manager = 'detect on host';
          }
        }
      } catch (_) {
        family = HostFamily.linux;
        manager = 'detect on host';
      }
    }

    if (mounted) {
      setState(() {
        _family = family;
        _osLabel = label;
        _packageManager = manager;
        _detected = true;
      });
    }
  }

  String _packageFor(String binary) {
    const archMap = {
      'nmap': 'nmap', 'masscan': 'masscan', 'ffuf': 'ffuf',
      'nuclei': 'nuclei', 'hydra': 'hydra', 'hashcat': 'hashcat',
      'sqlmap': 'sqlmap', 'nikto': 'nikto', 'dirb': 'dirb',
      'gobuster': 'gobuster', 'amass': 'amass', 'subfinder': 'subfinder',
      'dig': 'bind-tools', 'nslookup': 'bind-tools', 'host': 'bind-tools',
      'curl': 'curl', 'wget': 'wget', 'python3': 'python',
      'jq': 'jq', 'netcat': 'net-tools', 'nc': 'net-tools',
      'tcpdump': 'tcpdump', 'tshark': 'tshark', 'wireshark-cli': 'tshark',
      'aircrack-ng': 'aircrack-ng', 'airodump-ng': 'aircrack-ng',
      'sqlite3': 'sqlite', 'smbclient': 'samba', 'enum4linux': 'enum4linux-ng',
      'dnsenum': 'dnsenum', 'fierce': 'fierce', 'theharvester': 'theharvester',
    };
    const debMap = {
      'nmap': 'nmap', 'masscan': 'masscan', 'ffuf': 'ffuf',
      'nuclei': 'nuclei', 'hydra': 'hydra', 'hashcat': 'hashcat',
      'sqlmap': 'sqlmap', 'nikto': 'nikto', 'dirb': 'dirb',
      'gobuster': 'gobuster', 'amass': 'amass', 'subfinder': 'subfinder',
      'dig': 'dnsutils', 'nslookup': 'dnsutils', 'host': 'dnsutils',
      'curl': 'curl', 'wget': 'wget', 'python3': 'python3',
      'jq': 'jq', 'netcat': 'netcat-openbsd', 'nc': 'netcat-openbsd',
      'tcpdump': 'tcpdump', 'tshark': 'tshark', 'wireshark-cli': 'tshark',
      'aircrack-ng': 'aircrack-ng', 'airodump-ng': 'aircrack-ng',
      'sqlite3': 'sqlite3', 'smbclient': 'smbclient', 'enum4linux': 'enum4linux-ng',
      'dnsenum': 'dnsenum', 'fierce': 'fierce', 'theharvester': 'theharvester',
    };
    switch (_family) {
      case HostFamily.arch:
        return archMap[binary] ?? binary;
      case HostFamily.debian:
      case HostFamily.linux:
        return debMap[binary] ?? binary;
      default:
        return binary;
    }
  }

  Future<bool> _isInstalled(String binary) async {
    if (binary == 'native' || binary == '(native)') return true;
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [binary],
        runInShell: false,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkTools(Iterable<String> binaries) async {
    for (final binary in binaries) {
      if (binary == 'native' || binary == '(native)' || binary.isEmpty) continue;
      if (_checking.contains(binary)) continue;
      _checking.add(binary);
      final record = _tools.putIfAbsent(
        binary,
        () => ToolRecord(binary: binary, package: _packageFor(binary)),
      );
      final installed = await _isInstalled(binary);
      if (mounted) {
        setState(() {
          record.installed = installed;
          _checking.remove(binary);
        });
      }
    }
  }

  Future<void> _install(ToolRecord record) async {
    if (record.installing) return;
    if (_family == HostFamily.windows || _family == HostFamily.android) {
      setState(() {
        record.failed = true;
        record.note = 'Open a terminal and run: $_packageManager ${record.package}';
      });
      return;
    }
    setState(() {
      record.installing = true;
      record.failed = false;
      record.note = 'Running $_packageManager ${record.package}';
    });
    try {
      final args = _family == HostFamily.arch
          ? ['-S', '--noconfirm', '--needed', record.package]
          : ['install', '-y', record.package];
      final manager = _family == HostFamily.arch ? 'pacman' : 'apt-get';
      final result = await Process.run(manager, args, runInShell: false).timeout(
            const Duration(minutes: 5),
          );
      final ok = result.exitCode == 0;
      setState(() {
        record.installing = false;
        record.installed = ok;
        record.failed = !ok;
        record.note = ok
            ? 'Installed successfully'
            : (result.stderr ?? result.stdout ?? 'Install failed').toString().trim();
      });
    } catch (e) {
      setState(() {
        record.installing = false;
        record.failed = true;
        record.note = 'Install failed: $e';
      });
    }
  }

  Future<void> _installAll(List<ToolRecord> records) async {
    for (final record in records) {
      if (!record.installed) {
        await _install(record);
      }
    }
  }

  List<String> get _scopeBinaries {
    final capId = _capabilityId;
    if (capId == null) return CatalogUi.allTools;
    final cap = findCapability(capId);
    if (cap == null) return const [];
    final groups = CatalogUi.actionGroups(cap);
    if (_groupId == null) {
      return CatalogUi.toolsFor(cap);
    }
    ActionGroup? group;
    for (final g in groups) {
      if (g.id == _groupId) {
        group = g;
        break;
      }
    }
    if (group == null) return CatalogUi.toolsFor(cap);
    final ops = group.operations;
    final op = ops[_operationIndex.clamp(0, ops.length - 1)];
    return [op.binary];
  }

  double _progressFor(List<String> binaries) {
    if (binaries.isEmpty) return 1.0;
    int ready = 0;
    for (final b in binaries) {
      if (_tools[b]?.installed == true) ready++;
    }
    return ready / binaries.length;
  }

  @override
  Widget build(BuildContext context) {
    final phaseId = _phaseId;
    final caps = phaseId == null
        ? const <CapabilityEntry>[]
        : CatalogUi.capabilitiesIn(
            LoutePhase.values.firstWhere(
              (p) => p.name == phaseId,
              orElse: () => LoutePhase.recon,
            ),
          );
    final cap = _capabilityId == null ? null : findCapability(_capabilityId!);
    final groups = cap == null ? const <ActionGroup>[] : CatalogUi.actionGroups(cap);
    final scopeBinaries = _scopeBinaries;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scopeBinaries.isNotEmpty) _checkTools(scopeBinaries);
    });

    final scopeTools = scopeBinaries
        .where((b) => b != 'native' && b.isNotEmpty)
        .map((b) => _tools.putIfAbsent(
              b,
              () => ToolRecord(binary: b, package: _packageFor(b)),
            ))
        .toList();

    return Scaffold(
      backgroundColor: MidnightHacker.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('TOOL MANAGER',
                    style: MidnightHacker.headingLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  _detected ? '$_osLabel  /  $_packageManager' : 'Detecting host...',
                  style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Tools are installed with the host package manager using argv commands only. '
                  'No shell interpolation is used. Missing packages fall back to their binary name.',
                  style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                _buildProgressGrid(scopeBinaries),
                const SizedBox(height: 18),
                _buildBrowser(caps, groups, cap),
                const SizedBox(height: 18),
                _buildToolList(scopeTools),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressGrid(List<String> scopeBinaries) {
    final all = CatalogUi.allTools;
    final capBinaries = _capabilityId == null
        ? const <String>[]
        : findCapability(_capabilityId!)?.binaries ?? const <String>[];
    final items = [
      ('SYSTEM', _progressFor(all), all.length, () => _installAll(all.map((b) => _tools.putIfAbsent(b, () => ToolRecord(binary: b, package: _packageFor(b)))).toList())),
      ('PHASE', _progressFor(_phaseBinaries()), _phaseBinaries().length, () {}),
      ('CAPABILITY', _progressFor(capBinaries), capBinaries.length, () => _installAll(capBinaries.map((b) => _tools.putIfAbsent(b, () => ToolRecord(binary: b, package: _packageFor(b)))).toList())),
      ('ACTION', _progressFor(scopeBinaries), scopeBinaries.length, () => _installAll(scopeBinaries.map((b) => _tools.putIfAbsent(b, () => ToolRecord(binary: b, package: _packageFor(b)))).toList())),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: MidnightHacker.primary)),
      child: Column(
        children: items.map((item) {
          final label = item.$1 as String;
          final value = item.$2 as double;
          final count = item.$3 as int;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(width: 100, child: Text(label, style: MidnightHacker.monoSmall)),
                Expanded(child: ProgressBar(value: value, showPercentage: false, height: 8)),
                const SizedBox(width: 8),
                SizedBox(width: 70, child: Text('${(value * 100).round()}% / $count', style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 10))),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  height: 28,
                  child: OutlinedButton(
                    onPressed: count == 0 ? null : item.$4 as VoidCallback,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: MidnightHacker.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text('GET ALL',
                        style: MidnightHacker.monoSmall.copyWith(fontSize: 10)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<String> _phaseBinaries() {
    final phaseId = _phaseId;
    if (phaseId == null) return const [];
    final caps = CatalogUi.capabilitiesIn(
      LoutePhase.values.firstWhere(
        (p) => p.name == phaseId,
        orElse: () => LoutePhase.recon,
      ),
    );
    final set = <String>{};
    for (final c in caps) {
      for (final b in c.binaries) {
        set.add(b);
      }
    }
    return set.toList();
  }

  Widget _buildBrowser(
    List<CapabilityEntry> caps,
    List<ActionGroup> groups,
    CapabilityEntry? cap,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: MidnightHacker.dimGreen)),
      child: Column(
        children: [
          _dropdown(
            label: 'PHASE',
            value: _phaseId,
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('All phases')),
              ...CatalogUi.phases.map((p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.shortName),
                  )),
            ],
            onChanged: (v) => setState(() {
              _phaseId = v;
              _capabilityId = null;
              _groupId = null;
              _operationIndex = 0;
            }),
          ),
          const SizedBox(height: 8),
          _dropdown(
            label: 'CAPABILITY',
            value: _capabilityId,
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('All capabilities')),
              ...caps.map((c) => DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(c.label, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => setState(() {
              _capabilityId = v;
              _groupId = null;
              _operationIndex = 0;
            }),
          ),
          const SizedBox(height: 8),
          _dropdown(
            label: 'ACTION',
            value: _groupId,
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('All actions')),
              ...groups.map((g) => DropdownMenuItem<String>(
                    value: g.id,
                    child: Text(g.name),
                  )),
            ],
            onChanged: (v) => setState(() {
              _groupId = v;
              _operationIndex = 0;
            }),
          ),
          if (_groupId != null && groups.isNotEmpty) ...[
            const SizedBox(height: 8),
            _dropdown(
              label: 'SUB-ACTION',
              value: _subActionValue(groups),
              items: _subActionItems(groups),
              onChanged: (v) => setState(() => _operationIndex = int.tryParse(v ?? '0') ?? 0),
            ),
          ],
        ],
      ),
    );
  }

  String? _subActionValue(List<ActionGroup> groups) {
    ActionGroup? group;
    for (final g in groups) {
      if (g.id == _groupId) {
        group = g;
        break;
      }
    }
    if (group == null || group.operations.isEmpty) return null;
    return (_operationIndex.clamp(0, group.operations.length - 1)).toString();
  }

  List<DropdownMenuItem<String>> _subActionItems(List<ActionGroup> groups) {
    ActionGroup? group;
    for (final g in groups) {
      if (g.id == _groupId) {
        group = g;
        break;
      }
    }
    if (group == null) return const [];
    return List.generate(group.operations.length, (i) {
      final op = group!.operations[i];
      return DropdownMenuItem<String>(
        value: i.toString(),
        child: Text('${op.name}  ·  ${op.binary}', overflow: TextOverflow.ellipsis),
      );
    });
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: MidnightHacker.panelBg,
      decoration: InputDecoration(
        labelText: label,
        border: MidnightHacker.inputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      style: MidnightHacker.monoSmall,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildToolList(List<ToolRecord> tools) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: MidnightHacker.primary)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('REQUIRED TOOLS (${tools.length})',
                    style: MidnightHacker.heading.copyWith(fontSize: 14, letterSpacing: 1)),
                const Spacer(),
                Text('READY ${tools.where((t) => t.installed).length}/${tools.length}',
                    style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.positive)),
              ],
            ),
          ),
          const Divider(),
          if (tools.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Select a scope above to see required tools.',
                  style: MidnightHacker.labelDim, textAlign: TextAlign.center),
            )
          else
            ...tools.map((t) => _ToolRow(record: t, onInstall: () => _install(t))),
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  final ToolRecord record;
  final VoidCallback onInstall;

  const _ToolRow({required this.record, required this.onInstall});

  @override
  Widget build(BuildContext context) {
    final statusColor = record.installed
        ? MidnightHacker.positive
        : (record.failed ? MidnightHacker.negative : MidnightHacker.dimGreen);
    final status = record.installing
        ? 'DOWNLOADING'
        : (record.installed ? 'READY' : (record.failed ? 'FAILED' : 'MISSING'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: MidnightHacker.greenBorder)),
      child: Row(
        children: [
          Icon(
            record.installed ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.binary, style: MidnightHacker.monoSmall),
                if (record.note.isNotEmpty)
                  Text(record.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MidnightHacker.monoSmall.copyWith(
                        color: record.failed ? MidnightHacker.negative : MidnightHacker.dimGreen,
                        fontSize: 9,
                      )),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('package: ${record.package}',
                style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 10)),
          ),
          SizedBox(
            width: 80,
            child: Text(status,
                style: MidnightHacker.monoSmall.copyWith(color: statusColor, fontSize: 10),
                textAlign: TextAlign.right),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            height: 30,
            child: OutlinedButton.icon(
              onPressed: record.installed || record.installing ? null : onInstall,
              icon: record.installing
                  ? const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 2, color: MidnightHacker.primary),
                    )
                  : const Icon(Icons.download_outlined, size: 13),
              label: Text(record.installed ? 'OK' : 'GET',
                  style: MidnightHacker.monoSmall.copyWith(fontSize: 10)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: MidnightHacker.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
