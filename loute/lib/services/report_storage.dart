import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/report_model.dart';

class ReportStorage {
  static String createReportId() {
    final ts = DateTime.now();
    final rand = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'rpt_${ts.microsecondsSinceEpoch}_$rand';
  }

  static Future<ReportRecord> saveHtmlReport({
    required ReportPayload payload,
    required String baseDir,
    required String htmlContent,
  }) async {
    await _ensureDirectory(baseDir);

    final baseName = _buildBaseName(payload);
    final htmlPath = _join(baseDir, '$baseName.html');
    final rawPath = _join(baseDir, '$baseName.raw.html');
    final logPath = _join(baseDir, '$baseName.log.txt');
    final metaPath = _join(baseDir, '$baseName.meta.json');

    await File(htmlPath).writeAsString(htmlContent);
    await File(rawPath).writeAsString(payload.rawOutput);
    await File(logPath).writeAsString(payload.logs.join('\n'));

    final record = ReportRecord(
      id: payload.id,
      baseName: baseName,
      actionId: payload.actionId,
      actionName: payload.actionName,
      moduleName: payload.moduleName,
      phaseName: payload.phaseName,
      status: payload.status,
      timestamp: payload.timestamp,
      htmlPath: htmlPath,
      rawPath: rawPath,
      logPath: logPath,
      supportsCsv: payload.supportsCsv,
      supportsCve: payload.supportsCve,
      inputs: payload.inputs,
      findings: payload.findings,
    );

    await File(metaPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );

    return record;
  }

  static Future<ReportRecord> saveJsonReport({
    required ReportPayload payload,
    required ReportRecord record,
    required String baseDir,
    required String content,
  }) async {
    await _ensureDirectory(baseDir);
    final jsonPath = _join(baseDir, '${record.baseName}.json');
    await File(jsonPath).writeAsString(content);
    final updated = record.copyWith(jsonPath: jsonPath);
    await _updateMetadata(updated, baseDir);
    return updated;
  }

  static Future<ReportRecord> saveTxtReport({
    required ReportPayload payload,
    required ReportRecord record,
    required String baseDir,
    required String content,
  }) async {
    await _ensureDirectory(baseDir);
    final txtPath = _join(baseDir, '${record.baseName}.txt');
    await File(txtPath).writeAsString(content);
    final updated = record.copyWith(txtPath: txtPath);
    await _updateMetadata(updated, baseDir);
    return updated;
  }

  static Future<ReportRecord> saveCsvReport({
    required ReportPayload payload,
    required ReportRecord record,
    required String baseDir,
    required String content,
  }) async {
    await _ensureDirectory(baseDir);
    final csvPath = _join(baseDir, '${record.baseName}.csv');
    await File(csvPath).writeAsString(content);
    final updated = record.copyWith(csvPath: csvPath);
    await _updateMetadata(updated, baseDir);
    return updated;
  }

  static Future<ReportRecord> saveCveReport({
    required ReportPayload payload,
    required ReportRecord record,
    required String baseDir,
    required String content,
  }) async {
    await _ensureDirectory(baseDir);
    final cvePath = _join(baseDir, '${record.baseName}.cve.txt');
    await File(cvePath).writeAsString(content);
    final updated = record.copyWith(cvePath: cvePath);
    await _updateMetadata(updated, baseDir);
    return updated;
  }

  static Future<List<ReportRecord>> listReports(String baseDir) async {
    final dir = Directory(baseDir);
    if (!await dir.exists()) {
      return [];
    }

    final results = <ReportRecord>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.meta.json')) {
        try {
          final content = await entity.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          results.add(ReportRecord.fromJson(data));
        } catch (_) {}
      }
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  static Future<String?> readContent(ReportRecord record, ReportFormat format) async {
    final path = _pathForFormat(record, format);
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  static Future<void> editContent(ReportRecord record, ReportFormat format, String content) async {
    final path = _pathForFormat(record, format);
    if (path == null || path.isEmpty) return;
    await File(path).writeAsString(content);
  }

  static Future<void> deleteReport(ReportRecord record) async {
    final paths = [
      record.htmlPath,
      record.rawPath,
      record.jsonPath,
      record.txtPath,
      record.csvPath,
      record.cvePath,
      record.logPath,
      _join(_dirName(record.htmlPath), '${record.baseName}.meta.json'),
    ];

    for (final path in paths) {
      if (path == null || path.isEmpty) continue;
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<void> _updateMetadata(ReportRecord record, String baseDir) async {
    final metaPath = _join(baseDir, '${record.baseName}.meta.json');
    await File(metaPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );
  }

  static Future<void> _ensureDirectory(String baseDir) async {
    final dir = Directory(baseDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static String _buildBaseName(ReportPayload payload) {
    final ts = _formatTimestamp(payload.timestamp);
    final actionSlug = _sanitize(payload.actionName);
    return 'loute_recon_${actionSlug}_$ts';
  }

  static String _extractTarget(Map<String, String> inputs) {
    for (final key in [
      'target',
      'domain',
      'url',
      'cidr',
      'ip',
      'target_ip',
      'bucket',
      'bucket_name',
      'project_id',
      'nameserver',
    ]) {
      final value = inputs[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  static String _sanitize(String value) {
    final safe = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (safe.length <= 48) return safe;
    return safe.substring(0, 48);
  }

  static String _formatTimestamp(DateTime ts) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${ts.year}${two(ts.month)}${two(ts.day)}_${two(ts.hour)}${two(ts.minute)}${two(ts.second)}';
  }

  static String _join(String base, String file) {
    if (base.endsWith(Platform.pathSeparator)) {
      return '$base$file';
    }
    return '$base${Platform.pathSeparator}$file';
  }

  static String _dirName(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    if (idx == -1) return '.';
    return path.substring(0, idx);
  }

  static String? _pathForFormat(ReportRecord record, ReportFormat format) {
    switch (format) {
      case ReportFormat.html:
        return record.htmlPath;
      case ReportFormat.json:
        return record.jsonPath;
      case ReportFormat.txt:
        return record.txtPath;
      case ReportFormat.csv:
        return record.csvPath;
      case ReportFormat.cve:
        return record.cvePath;
      case ReportFormat.md:
      case ReportFormat.sarif:
      case ReportFormat.pdf:
        return null;
    }
  }
}
