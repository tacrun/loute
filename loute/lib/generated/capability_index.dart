// capability_index.dart — Generated from capabilities.toml.txt
// This is the Flutter-side typed index of the LOUTE capability catalog.
// Per 1-5-5.md §8.5: Flutter never parses TOML; it imports this generated index.
//
// LOUTE V1.5.5 | 11 phases | 241 capabilities

// Generated index — Phase enum
enum LoutePhase {
  recon,
  surface,
  vulnerability,
  payload,
  escalation,
  credentials,
  lateral,
  persistence,
  exploitation,
  wireless,
  ctf;

  String get displayName {
    switch (this) {
      case recon: return 'RECONNAISSANCE';
      case surface: return 'ATTACK SURFACE';
      case vulnerability: return 'VULNERABILITY';
      case payload: return 'PAYLOAD';
      case escalation: return 'ESCALATION';
      case credentials: return 'CREDENTIALS';
      case lateral: return 'LATERAL';
      case persistence: return 'PERSISTENCE';
      case exploitation: return 'EXPLOITATION';
      case wireless: return 'WIRELESS';
      case ctf: return 'CTF CHALLENGES';
    }
  }

  static LoutePhase fromString(String s) {
    return LoutePhase.values.firstWhere(
      (p) => p.name == s.toLowerCase(),
      orElse: () => LoutePhase.recon,
    );
  }
}

// Risk tiers
enum LouteRisk { r0, r1, r2, r3, r4 }

// Noise levels
enum LouteNoise { silent, low, medium, high, screaming }

// Capability summary — mirrors the Rust CapabilitySummaryFrb struct
class CapabilitySummary {
  final String id;
  final String phase;
  final String label;
  final String summary;
  final String risk;
  final String noise;
  final String provider;
  final bool native;
  final bool opsecSafe;
  final String availability;

  CapabilitySummary({
    required this.id,
    required this.phase,
    required this.label,
    required this.summary,
    required this.risk,
    required this.noise,
    required this.provider,
    required this.native,
    required this.opsecSafe,
    required this.availability,
  });

  LoutePhase get loutePhase => LoutePhase.fromString(phase);
  LouteRisk get louteRisk => LouteRisk.values.firstWhere(
    (r) => r.name == risk.toLowerCase().replaceAll('r', 'r'),
    orElse: () => LouteRisk.r1,
  );
  LouteNoise get louteNoise => LouteNoise.values.firstWhere(
    (n) => n.name == noise.toLowerCase(),
    orElse: () => LouteNoise.medium,
  );

  factory CapabilitySummary.fromJson(Map<String, dynamic> json) {
    return CapabilitySummary(
      id: json['id'] ?? '',
      phase: json['phase'] ?? 'recon',
      label: json['label'] ?? '',
      summary: json['summary'] ?? '',
      risk: json['risk'] ?? 'R1',
      noise: json['noise'] ?? 'medium',
      provider: json['provider'] ?? 'native',
      native: json['native'] ?? false,
      opsecSafe: json['opsec_safe'] ?? false,
      availability: json['availability'] ?? 'probing',
    );
  }
}

// Capability detail — mirrors the Rust CapabilityDetailFrb struct
class CapabilityDetail {
  final String id;
  final String phase;
  final String label;
  final String summary;
  final String risk;
  final String noise;
  final List<String> mitre;
  final List<String> platforms;
  final List<String> privileges;
  final bool network;
  final List<String> requires;
  final List<String> provides;
  final List<InputSpec> inputs;
  final String provider;
  final String binary;
  final String operation;
  final List<String> args;
  final String output;
  final String parser;
  final int timeout;
  final int concurrency;
  final bool native;
  final bool opsecSafe;
  final bool reversible;
  final List<String> chains;
  final String availability;

  CapabilityDetail({
    required this.id,
    required this.phase,
    required this.label,
    required this.summary,
    required this.risk,
    required this.noise,
    required this.mitre,
    required this.platforms,
    required this.privileges,
    required this.network,
    required this.requires,
    required this.provides,
    required this.inputs,
    required this.provider,
    required this.binary,
    required this.operation,
    required this.args,
    required this.output,
    required this.parser,
    required this.timeout,
    required this.concurrency,
    required this.native,
    required this.opsecSafe,
    required this.reversible,
    required this.chains,
    required this.availability,
  });

  LoutePhase get loutePhase => LoutePhase.fromString(phase);

  factory CapabilityDetail.fromJson(Map<String, dynamic> json) {
    return CapabilityDetail(
      id: json['id'] ?? '',
      phase: json['phase'] ?? 'recon',
      label: json['label'] ?? '',
      summary: json['summary'] ?? '',
      risk: json['risk'] ?? 'R1',
      noise: json['noise'] ?? 'medium',
      mitre: List<String>.from(json['mitre'] ?? []),
      platforms: List<String>.from(json['platforms'] ?? []),
      privileges: List<String>.from(json['privileges'] ?? []),
      network: json['network'] ?? true,
      requires: List<String>.from(json['requires'] ?? []),
      provides: List<String>.from(json['provides'] ?? []),
      inputs: (json['inputs'] as List?)
          ?.map((i) => InputSpec.fromJson(i as Map<String, dynamic>))
          .toList() ?? [],
      provider: json['provider'] ?? 'native',
      binary: json['binary'] ?? 'native',
      operation: json['operation'] ?? 'default',
      args: List<String>.from(json['args'] ?? []),
      output: json['output'] ?? 'lines',
      parser: json['parser'] ?? 'lines',
      timeout: json['timeout'] ?? 900,
      concurrency: json['concurrency'] ?? 4,
      native: json['native'] ?? false,
      opsecSafe: json['opsec_safe'] ?? false,
      reversible: json['reversible'] ?? false,
      chains: List<String>.from(json['chains'] ?? []),
      availability: json['availability'] ?? 'probing',
    );
  }
}

// Input specification
class InputSpec {
  final String name;
  final String kind;
  final bool required;
  final String? defaultValue;

  InputSpec({
    required this.name,
    required this.kind,
    required this.required,
    this.defaultValue,
  });

  factory InputSpec.fromJson(Map<String, dynamic> json) {
    return InputSpec(
      name: json['name'] ?? '',
      kind: json['kind'] ?? 'text',
      required: json['required'] ?? false,
      defaultValue: json['default'],
    );
  }
}

// Provider health — mirrors ProviderHealthFrb
class ProviderHealth {
  final String name;
  final String binary;
  final String state;
  final String version;
  final int capabilityCount;
  final String installHint;

  ProviderHealth({
    required this.name,
    required this.binary,
    required this.state,
    required this.version,
    required this.capabilityCount,
    required this.installHint,
  });

  factory ProviderHealth.fromJson(Map<String, dynamic> json) {
    return ProviderHealth(
      name: json['name'] ?? '',
      binary: json['binary'] ?? '',
      state: json['state'] ?? 'probing',
      version: json['version'] ?? '',
      capabilityCount: json['capability_count'] ?? 0,
      installHint: json['install_hint'] ?? '',
    );
  }
}

// Static metadata about the catalog
class CatalogMeta {
  static const String version = '1.5.5';
  static const int schemaVersion = 1;
  static const int totalCapabilities = 241;
  static const int totalPhases = 11;

  static const Map<String, int> phaseCounts = {
    'recon': 22,
    'surface': 22,
    'vulnerability': 22,
    'payload': 21,
    'escalation': 24,
    'credentials': 22,
    'lateral': 26,
    'persistence': 19,
    'exploitation': 27,
    'wireless': 21,
    'ctf': 15,
  };
}
