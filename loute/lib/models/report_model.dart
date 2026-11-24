import 'dart:convert';

enum ReportFormat { html, json, txt, csv, cve, md, sarif, pdf }

class ReportPayload {
  final String id;
  final String actionId;
  final String actionName;
  final String moduleName;
  final String phaseName;
  final String status;
  final String systemVersion;
  final DateTime timestamp;
  final Map<String, String> inputs;
  final List<String> logs;
  final String rawOutput;
  final List<Map<String, dynamic>> findings;
  final bool supportsCsv;
  final bool supportsCve;

  ReportPayload({
    required this.id,
    required this.actionId,
    required this.actionName,
    required this.moduleName,
    required this.phaseName,
    required this.status,
    required this.systemVersion,
    required this.timestamp,
    required this.inputs,
    required this.logs,
    required this.rawOutput,
    this.findings = const [],
    this.supportsCsv = false,
    this.supportsCve = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actionId': actionId,
      'actionName': actionName,
      'moduleName': moduleName,
      'phaseName': phaseName,
      'status': status,
      'systemVersion': systemVersion,
      'timestamp': timestamp.toIso8601String(),
      'inputs': inputs,
      'logs': logs,
      'rawOutput': rawOutput,
      'findings': findings,
      'supportsCsv': supportsCsv,
      'supportsCve': supportsCve,
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class ReportRecord {
  final String id;
  final String baseName;
  final String actionId;
  final String actionName;
  final String moduleName;
  final String phaseName;
  final String status;
  final DateTime timestamp;
  final String htmlPath;
  final String? rawPath;
  final String? jsonPath;
  final String? txtPath;
  final String? csvPath;
  final String? cvePath;
  final String? logPath;
  final bool supportsCsv;
  final bool supportsCve;
  final Map<String, String> inputs;
  final List<Map<String, dynamic>> findings;

  ReportRecord({
    required this.id,
    required this.baseName,
    required this.actionId,
    required this.actionName,
    required this.moduleName,
    required this.phaseName,
    required this.status,
    required this.timestamp,
    required this.htmlPath,
    this.rawPath,
    this.jsonPath,
    this.txtPath,
    this.csvPath,
    this.cvePath,
    this.logPath,
    this.supportsCsv = false,
    this.supportsCve = false,
    this.inputs = const {},
    this.findings = const [],
  });

  ReportRecord copyWith({
    String? baseName,
    String? htmlPath,
    String? rawPath,
    String? jsonPath,
    String? txtPath,
    String? csvPath,
    String? cvePath,
    String? logPath,
    bool? supportsCsv,
    bool? supportsCve,
    Map<String, String>? inputs,
    List<Map<String, dynamic>>? findings,
  }) {
    return ReportRecord(
      id: id,
      baseName: baseName ?? this.baseName,
      actionId: actionId,
      actionName: actionName,
      moduleName: moduleName,
      phaseName: phaseName,
      status: status,
      timestamp: timestamp,
      htmlPath: htmlPath ?? this.htmlPath,
      rawPath: rawPath ?? this.rawPath,
      jsonPath: jsonPath ?? this.jsonPath,
      txtPath: txtPath ?? this.txtPath,
      csvPath: csvPath ?? this.csvPath,
      cvePath: cvePath ?? this.cvePath,
      logPath: logPath ?? this.logPath,
      supportsCsv: supportsCsv ?? this.supportsCsv,
      supportsCve: supportsCve ?? this.supportsCve,
      inputs: inputs ?? this.inputs,
      findings: findings ?? this.findings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baseName': baseName,
      'actionId': actionId,
      'actionName': actionName,
      'moduleName': moduleName,
      'phaseName': phaseName,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'htmlPath': htmlPath,
      'rawPath': rawPath,
      'jsonPath': jsonPath,
      'txtPath': txtPath,
      'csvPath': csvPath,
      'cvePath': cvePath,
      'logPath': logPath,
      'supportsCsv': supportsCsv,
      'supportsCve': supportsCve,
      'inputs': inputs,
      'findings': findings,
    };
  }

  static ReportRecord fromJson(Map<String, dynamic> json) {
    DateTime ts;
    try {
      ts = DateTime.parse(json['timestamp'] as String);
    } catch (_) {
      ts = DateTime.now();
    }

    final rawInputs = json['inputs'];
    Map<String, String> inputs = {};
    if (rawInputs is Map) {
      rawInputs.forEach((key, value) {
        inputs[key.toString()] = value?.toString() ?? '';
      });
    }

    final rawFindings = json['findings'];
    List<Map<String, dynamic>> findings = const [];
    if (rawFindings is List) {
      findings = rawFindings.whereType<Map>().map((f) {
        return f.map((k, v) => MapEntry(k.toString(), v));
      }).toList();
    }

    return ReportRecord(
      id: json['id']?.toString() ?? 'unknown',
      baseName: json['baseName']?.toString() ?? 'report',
      actionId: json['actionId']?.toString() ?? 'unknown',
      actionName: json['actionName']?.toString() ?? 'Unknown Action',
      moduleName: json['moduleName']?.toString() ?? '',
      phaseName: json['phaseName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      timestamp: ts,
      htmlPath: json['htmlPath']?.toString() ?? '',
      rawPath: json['rawPath']?.toString(),
      jsonPath: json['jsonPath']?.toString(),
      txtPath: json['txtPath']?.toString(),
      csvPath: json['csvPath']?.toString(),
      cvePath: json['cvePath']?.toString(),
      logPath: json['logPath']?.toString(),
      supportsCsv: json['supportsCsv'] == true,
      supportsCve: json['supportsCve'] == true,
      inputs: inputs,
      findings: findings,
    );
  }
}
