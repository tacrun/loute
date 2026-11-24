// catalog_ui.dart - UI helpers derived from the generated capability catalog.
// This is the only source of phase, capability, action and wordlist structure
// used by the operator interface. No fabricated registry is involved.

import 'package:flutter/material.dart';
import '../generated/capability_index.dart';
import '../generated/wordlist_index.dart';

/// Static metadata for the eleven real catalog phases.
class PhaseInfo {
  final LoutePhase phase;
  final IconData icon;
  final String description;

  const PhaseInfo({
    required this.phase,
    required this.icon,
    required this.description,
  });

  String get id => phase.name;
  String get name => phase.displayName;
  String get shortName => phase.shortName;
}

/// A stable action group. Operations are grouped into a small set of
/// semantic categories so an operator sees 2 to 5 brief action cards instead
/// of a raw list of dozens of command templates.
class ActionGroup {
  final String id;
  final String name;
  final IconData icon;
  final List<CapOperation> operations;

  const ActionGroup({
    required this.id,
    required this.name,
    required this.icon,
    required this.operations,
  });
}

/// Wordlist category hint for an input or a capability context.
class WordlistHint {
  final String category;
  final String label;

  const WordlistHint(this.category, this.label);
}

class CatalogUi {
  CatalogUi._();

  static const List<PhaseInfo> phases = [
    PhaseInfo(phase: LoutePhase.recon, icon: Icons.radar_outlined, description: 'Passive and active target discovery'),
    PhaseInfo(phase: LoutePhase.surface, icon: Icons.public_outlined, description: 'Exposed attack surface mapping'),
    PhaseInfo(phase: LoutePhase.vulnerability, icon: Icons.vulnerability_outlined, description: 'Vulnerability detection and validation'),
    PhaseInfo(phase: LoutePhase.payload, icon: Icons.data_object_outlined, description: 'Payload generation and delivery'),
    PhaseInfo(phase: LoutePhase.escalation, icon: Icons.arrow_upward_outlined, description: 'Privilege escalation paths'),
    PhaseInfo(phase: LoutePhase.credentials, icon: Icons.key_outlined, description: 'Credential discovery and testing'),
    PhaseInfo(phase: LoutePhase.lateral, icon: Icons.swap_horiz_outlined, description: 'Lateral movement across hosts'),
    PhaseInfo(phase: LoutePhase.persistence, icon: Icons.lock_outlined, description: 'Persistence mechanisms'),
    PhaseInfo(phase: LoutePhase.exploitation, icon: Icons.bolt_outlined, description: 'Exploit execution and control'),
    PhaseInfo(phase: LoutePhase.wireless, icon: Icons.wifi_outlined, description: 'Wireless and radio assessment'),
    PhaseInfo(phase: LoutePhase.ctf, icon: Icons.flag_outlined, description: 'CTF challenge solving workflows'),
  ];

  static final Map<String, PhaseInfo> _phaseById = {
    for (final p in phases) p.id: p,
  };

  static PhaseInfo phaseById(String id) =>
      _phaseById[id] ?? phases.first;

  static PhaseInfo phaseFor(CapabilityEntry cap) => phaseById(cap.phase);

  static List<CapabilityEntry> capabilitiesIn(LoutePhase phase) =>
      byPhaseEnum(phase);

  static int capabilityCount(LoutePhase phase) =>
      capabilitiesIn(phase).length;

  static List<CapabilityEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return kCapabilities;
    return kCapabilities.where((c) =>
        c.id.toLowerCase().contains(q) ||
        c.label.toLowerCase().contains(q) ||
        c.summary.toLowerCase().contains(q) ||
        c.provider.toLowerCase().contains(q)).toList();
  }

  /// A deterministic, distinct icon per capability. The icon is chosen from
  /// the phase family plus a stable hash of the capability id so every
  /// capability in the sidebar has its own recognizable glyph.
  static IconData iconFor(CapabilityEntry cap) {
    final byId = <String, IconData>{
      'recon.subdomain-enum': Icons.travel_explore_outlined,
      'recon.port-scan': Icons.scanner_outlined,
      'credentials.password-spray': Icons.password_outlined,
      'credentials.ssh-bruteforce': Icons.terminal_outlined,
      'wireless.wifi-handshake': Icons.wifi_outlined,
      'ctf.digital-forensics': Icons.search_outlined,
    };
    if (byId.containsKey(cap.id)) return byId[cap.id]!;

    final family = _phaseIcons[cap.phase] ?? Icons.circle_outlined;
    final variants = _phaseIconVariants[cap.phase] ?? const <IconData>[];
    if (variants.isEmpty) return family;
    return variants[stableHash(cap.id) % variants.length];
  }

  static const Map<String, IconData> _phaseIcons = {
    'recon': Icons.radar_outlined,
    'surface': Icons.public_outlined,
    'vulnerability': Icons.vulnerability_outlined,
    'payload': Icons.data_object_outlined,
    'escalation': Icons.arrow_upward_outlined,
    'credentials': Icons.key_outlined,
    'lateral': Icons.swap_horiz_outlined,
    'persistence': Icons.lock_outlined,
    'exploitation': Icons.bolt_outlined,
    'wireless': Icons.wifi_outlined,
    'ctf': Icons.flag_outlined,
  };

  static const Map<String, List<IconData>> _phaseIconVariants = {
    'recon': [Icons.radar_outlined, Icons.dns_outlined, Icons.language_outlined, Icons.cloud_outlined, Icons.route_outlined, Icons.search_outlined],
    'surface': [Icons.public_outlined, Icons.web_outlined, Icons.http_outlined, Icons.storage_outlined, Icons.dns_outlined, Icons.api_outlined],
    'vulnerability': [Icons.vulnerability_outlined, Icons.virus_outlined, Icons.gpp_bad_outlined, Icons.security_outlined, Icons.bug_report_outlined, Icons.shield_outlined],
    'payload': [Icons.data_object_outlined, Icons.code_outlined, Icons.input_outlined, Icons.terminal_outlined, Icons.content_paste_outlined, Icons.memory_outlined],
    'escalation': [Icons.arrow_upward_outlined, Icons.admin_panel_settings_outlined, Icons.key_outlined, Icons.account_tree_outlined, Icons.security_outlined, Icons.lock_open_outlined],
    'credentials': [Icons.key_outlined, Icons.password_outlined, Icons.fingerprint_outlined, Icons.login_outlined, Icons.vpn_key_outlined, Icons.badge_outlined],
    'lateral': [Icons.swap_horiz_outlined, Icons.lan_outlined, Icons.devices_outlined, Icons.computer_outlined, Icons.sensors_outlined, Icons.network_check_outlined],
    'persistence': [Icons.lock_outlined, Icons.schedule_outlined, Icons.settings_outlined, Icons.archive_outlined, Icons.bookmark_outlined, Icons.install_desktop_outlined],
    'exploitation': [Icons.bolt_outlined, Icons.fireplace_outlined, Icons.flash_on_outlined, Icons.gavel_outlined, Icons.model_training_outlined, Icons.whatshot_outlined],
    'wireless': [Icons.wifi_outlined, Icons.bluetooth_outlined, Icons.cell_wifi_outlined, Icons.router_outlined, Icons.sensors_outlined, Icons.rss_feed_outlined],
    'ctf': [Icons.flag_outlined, Icons.emoji_events_outlined, Icons.extension_outlined, Icons.puzzle_outlined, Icons.psychology_outlined, Icons.front_hand_outlined],
  };

  static int stableHash(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = ((h << 5) - h + c) & 0x7fffffff;
    }
    return h;
  }

  /// Group a capability's operations into a small set of semantic actions.
  /// Group order is fixed; only non-empty groups are returned. Sub-actions
  /// inside each group keep their catalog stage order so chaining survives.
  static List<ActionGroup> actionGroups(CapabilityEntry cap) {
    final buckets = <String, List<CapOperation>>{
      'discovery': [],
      'access': [],
      'credentials': [],
      'harvest': [],
      'analysis': [],
    };

    for (final op in cap.operations) {
      buckets[_actionCategory(op)]!.add(op);
    }

    const defs = [
      ('discovery', 'Surface Discovery', Icons.radar_outlined),
      ('access', 'Target Access', Icons.http_outlined),
      ('credentials', 'Credential Attack', Icons.key_outlined),
      ('harvest', 'Data Harvest', Icons.storage_outlined),
      ('analysis', 'Deep Analysis', Icons.analytics_outlined),
    ];

    final groups = <ActionGroup>[];
    for (final (id, name, icon) in defs) {
      final ops = buckets[id]!;
      if (ops.isEmpty) continue;
      ops.sort((a, b) => a.stage.compareTo(b.stage));
      groups.add(ActionGroup(id: id, name: name, icon: icon, operations: ops));
    }
    return groups;
  }

  static String _actionCategory(CapOperation op) {
    final text = '${op.name} ${op.binary} ${op.args.join(' ')}'.toLowerCase();
    if (_matches(text, const [
      'password', 'passwd', 'hash', 'crack', 'brute', 'login', 'auth',
      'credential', 'decrypt', 'kerberos', 'ntlm', 'samba', 'ssh', 'token',
      'secret', 'john', 'hashcat', 'hydra',
    ])) {
      return 'credentials';
    }
    if (_matches(text, const [
      'extract', 'dump', 'download', 'harvest', 'carve', 'recover',
      'collect', 'export', 'read', 'cat ', 'strings', 'sqlite', 'registry',
      'forensic', 'memory', 'artifact', 'loot',
    ])) {
      return 'harvest';
    }
    if (_matches(text, const [
      'parse', 'decode', 'analyze', 'inspect', 'format', 'diff', 'compare',
      'verify', 'validate', 'json', 'xml', 'report', 'stats', 'count',
      'sort', 'filter', 'grep', 'jq ', 'python',
    ])) {
      return 'analysis';
    }
    if (op.probe ||
        _matches(text, const [
          'scan', 'discover', 'enumerate', 'list', 'find', 'identify',
          'detect', 'check', 'probe', 'whois', 'lookup', 'resolve', 'search',
          'fuzz', 'bruteforce', 'subdomain', 'port', 'banner',
        ])) {
      return 'discovery';
    }
    return 'access';
  }

  static bool _matches(String text, List<String> keys) {
    for (final k in keys) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  /// Return the wordlist category that best fits an input, or null when the
  /// input is not wordlist backed. Context comes from the input kind/name and
  /// from the capability phase and tool set.
  static WordlistHint? wordlistHint(CapInputDef input, CapabilityEntry cap) {
    final key = input.key.toLowerCase();
    final kind = input.type.toLowerCase();

    if (kind == 'username' || key.contains('user') || key.contains('login')) {
      return const WordlistHint('users', 'Usernames');
    }
    if (kind == 'password' || key.contains('pass') || key.contains('secret')) {
      return const WordlistHint('passwords', 'Passwords');
    }
    if (key.contains('wordlist') || key.contains('list') || kind == 'list') {
      final c = _categoryForCapability(cap);
      return WordlistHint(c, kWordlistCategoryLabels[c] ?? c);
    }
    return null;
  }

  static String _categoryForCapability(CapabilityEntry cap) {
    final text = '${cap.phase} ${cap.binary} ${cap.label} ${cap.provider}'
        .toLowerCase();
    if (_matches(text, const ['wifi', 'wireless', 'wpa', 'aircrack'])) return 'wifi';
    if (_matches(text, const ['dns', 'subdomain', 'host', 'domain'])) return 'dns';
    if (_matches(text, const ['web', 'http', 'url', 'dir', 'param', 'api'])) return 'web';
    if (_matches(text, const ['smb', 'netbios', 'samba'])) return 'smb';
    if (_matches(text, const ['ssh', 'telnet'])) return 'ssh';
    if (_matches(text, const ['active', 'directory', 'ldap', 'ad '])) return 'ad';
    if (_matches(text, const ['db', 'mysql', 'postgres', 'oracle', 'sql'])) return 'db';
    if (_matches(text, const ['fuzz', 'payload', 'xss', 'lfi', 'sqli'])) return 'fuzz';
    if (_matches(text, const ['rule', 'hashcat', 'john'])) return 'rules';
    return 'passwords';
  }

  /// Distinct tool binaries used by a capability, in stable order.
  static List<String> toolsFor(CapabilityEntry cap) => cap.binaries;

  /// Total operation count across the whole catalog.
  static int get totalOperations =>
      kCapabilities.fold<int>(0, (sum, c) => sum + c.operations.length);

  /// Distinct tool binaries across the whole catalog.
  static List<String> get allTools {
    final set = <String>{};
    for (final c in kCapabilities) {
      for (final op in c.operations) {
        if (op.binary.isNotEmpty) set.add(op.binary);
      }
    }
    final list = set.toList()..sort();
    return list;
  }
}
