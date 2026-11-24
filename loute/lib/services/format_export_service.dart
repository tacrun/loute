import 'dart:io';
import '../models/report_model.dart';
import '../engines/html_engine.dart';
import '../engines/json_engine.dart';
import '../engines/csv_engine.dart';
import '../engines/txt_engine.dart';
import '../engines/cve_engine.dart';
import '../engines/md_engine.dart';
import '../engines/sarif_engine.dart';
import '../engines/pdf_engine.dart';

/// Generates and exports reports in all available formats
class FormatExportService {
  /// Generate all format files for a report
  static Future<Map<String, String>> generateAllFormats({
    required ReportPayload payload,
    required String outputDirectory,
    required String logoBase64,
  }) async {
    final files = <String, String>{};

    try {
      // Create output directory if it doesn't exist
      final dir = Directory(outputDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final baseName = _buildFileName(payload);

      // Generate HTML (primary format)
      final htmlContent = HtmlEngine.render(payload, logoBase64);
      final htmlPath =
          await _saveFile(outputDirectory, '$baseName.html', htmlContent);
      files['html'] = htmlPath;

      // Generate JSON
      final jsonContent = JsonEngine.render(payload);
      final jsonPath =
          await _saveFile(outputDirectory, '$baseName.json', jsonContent);
      files['json'] = jsonPath;

      // Generate CSV (only if there are findings to export)
      if (payload.findings.isNotEmpty || payload.supportsCsv) {
        final csvContent = CsvEngine.render(payload);
        final csvPath =
            await _saveFile(outputDirectory, '$baseName.csv', csvContent);
        files['csv'] = csvPath;
      }

      // Generate TXT
      final txtContent = TxtEngine.render(payload);
      final txtPath =
          await _saveFile(outputDirectory, '$baseName.txt', txtContent);
      files['txt'] = txtPath;

      // Generate CVE (if applicable)
      if (payload.supportsCve) {
        final cveContent = CveEngine.render(payload);
        final cvePath =
            await _saveFile(outputDirectory, '$baseName.cve', cveContent);
        files['cve'] = cvePath;
      }

      // Markdown (repo/PR friendly, includes provenance appendix)
      final mdContent = MdEngine.render(payload);
      files['md'] = await _saveFile(outputDirectory, '$baseName.md', mdContent);

      // SARIF (CI integration)
      final sarifContent = SarifEngine.render(payload);
      files['sarif'] =
          await _saveFile(outputDirectory, '$baseName.sarif', sarifContent);

      // PDF (print deliverable, self-contained)
      final pdfBytes = PdfEngine.renderBytes(payload);
      files['pdf'] =
          await _saveBytes(outputDirectory, '$baseName.pdf', pdfBytes);

      return files;
    } catch (e) {
      print('Error generating format files: $e');
      rethrow;
    }
  }

  /// Save file to disk
  static Future<String> _saveFile(
    String directory,
    String filename,
    String content,
  ) async {
    final filepath = '$directory/$filename';
    final file = File(filepath);

    try {
      await file.writeAsString(content, flush: true);
      print('✓ Saved: $filepath');
      return filepath;
    } catch (e) {
      print('✗ Failed to save $filepath: $e');
      rethrow;
    }
  }

  /// Save raw bytes to disk (binary formats such as PDF)
  static Future<String> _saveBytes(
    String directory,
    String filename,
    List<int> content,
  ) async {
    final filepath = '$directory/$filename';
    final file = File(filepath);
    try {
      await file.writeAsBytes(content, flush: true);
      print('✓ Saved: $filepath');
      return filepath;
    } catch (e) {
      print('✗ Failed to save $filepath: $e');
      rethrow;
    }
  }

  /// Build standardized filename for reports
  static String _buildFileName(ReportPayload payload) {
    final ts = payload.timestamp;
    final timestamp =
        '${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}${ts.second.toString().padLeft(2, '0')}';
    final actionSlug = _sanitize(payload.actionName);
    final targetSlug = _sanitize(_extractTarget(payload.inputs));
    final targetPart = targetSlug.isEmpty ? 'target' : targetSlug;
    final status = payload.status.toUpperCase();

    return 'loute_${actionSlug}_${targetPart}_${timestamp}_${status}_${payload.id}';
  }

  /// Extract target from inputs
  static String _extractTarget(Map<String, String> inputs) {
    for (final key in [
      'target',
      'domain',
      'url',
      'cidr',
      'ip',
      'bucket',
      'bucket_name',
      'project_id',
      'project',
    ]) {
      if (inputs.containsKey(key)) {
        return inputs[key] ?? '';
      }
    }
    return '';
  }

  /// Sanitize strings for use in filenames
  static String _sanitize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Get file size in human-readable format
  static String formatFileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;

    while (size > 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  /// Get file statistics
  static Future<Map<String, dynamic>> getFileStats(String filepath) async {
    try {
      final file = File(filepath);
      if (!await file.exists()) {
        return {'exists': false};
      }

      final stat = await file.stat();
      return {
        'exists': true,
        'path': filepath,
        'size': stat.size,
        'size_formatted': formatFileSize(stat.size),
        'modified': stat.modified.toUtc().toIso8601String(),
        'filename': file.path.split('/').last,
      };
    } catch (e) {
      return {'exists': false, 'error': e.toString()};
    }
  }

  /// List all generated report files for an action
  static Future<List<Map<String, dynamic>>> listReportFiles(
    String outputDirectory,
    String actionId,
  ) async {
    try {
      final dir = Directory(outputDirectory);
      if (!await dir.exists()) {
        return [];
      }

      final files = <Map<String, dynamic>>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.contains(actionId)) {
          final stats = await getFileStats(entity.path);
          files.add(stats);
        }
      }
      return files.where((f) => f['exists'] == true).toList();
    } catch (e) {
      print('Error listing report files: $e');
      return [];
    }
  }

  /// Clear old reports (keeps last N reports per action)
  static Future<void> cleanupOldReports(
    String outputDirectory, {
    int keepPerAction = 5,
  }) async {
    try {
      final dir = Directory(outputDirectory);
      if (!await dir.exists()) return;

      final files = await dir.list().toList();
      final groupedByAction = <String, List<FileSystemEntity>>{};

      // Group files by action
      for (final entity in files) {
        if (entity is File) {
          final filename = entity.path.split('/').last;
          final actionName = filename.split('_').skip(1).take(3).join('_');
          groupedByAction.putIfAbsent(actionName, () => []).add(entity);
        }
      }

      // Sort by modification time and delete old ones
      for (final entries in groupedByAction.values) {
        if (entries.length > keepPerAction) {
          entries.sort((a, b) {
            final aFile = a as File;
            final bFile = b as File;
            return bFile
                .statSync()
                .modified
                .compareTo(aFile.statSync().modified);
          });

          for (var i = keepPerAction; i < entries.length; i++) {
            await (entries[i] as File).delete();
            print('Deleted old report: ${entries[i].path}');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up old reports: $e');
    }
  }
}
