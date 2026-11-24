import '../models/report_model.dart';

/// Markdown report engine - repo/PR friendly (1-5-5.md §15.1).
/// Includes provenance appendix (§15.4).
class MdEngine {
  static String render(ReportPayload payload) {
    final b = StringBuffer();
    b.writeln('# LOUTE Report - ${payload.actionName}');
    b.writeln();
    b.writeln(
        '> LOUTE V${payload.systemVersion} · Generated ${payload.timestamp.toIso8601String()}');
    b.writeln();
    b.writeln('## Summary');
    b.writeln();
    b.writeln('- **Action:** ${payload.actionName} (${payload.actionId})');
    b.writeln(
        '- **Phase / Module:** ${payload.phaseName} / ${payload.moduleName}');
    b.writeln('- **Status:** ${payload.status}');
    b.writeln();
    if (payload.inputs.isNotEmpty) {
      b.writeln('## Scope & Inputs');
      b.writeln();
      b.writeln('| Key | Value |');
      b.writeln('|---|---|');
      payload.inputs.forEach((k, v) => b.writeln('| `$k` | ${_esc(v)} |'));
      b.writeln();
    }
    if (payload.findings.isNotEmpty) {
      b.writeln('## Findings');
      b.writeln();
      b.writeln('| Severity | Title | Detail |');
      b.writeln('|---|---|---|');
      for (final f in payload.findings) {
        b.writeln(
            '| ${_esc(f['severity']?.toString() ?? 'info')} | ${_esc(f['title']?.toString() ?? '')} | ${_esc(f['detail']?.toString() ?? '')} |');
      }
      b.writeln();
    }
    if (payload.rawOutput.isNotEmpty) {
      b.writeln('## Raw Output');
      b.writeln();
      b.writeln('```text');
      b.writeln(payload.rawOutput);
      b.writeln('```');
      b.writeln();
    }
    b.writeln('## Provenance');
    b.writeln();
    b.writeln(
        '- Catalog SHA-256: `${payload.inputs['catalog_hash'] ?? 'embedded'}`');
    b.writeln(
        '- Provider version: `${payload.inputs['provider_version'] ?? 'n/a'}`');
    b.writeln(
        '- Command: `${payload.inputs['command_preview'] ?? payload.actionId}`');
    b.writeln('- Report ID: `${payload.id}`');
    return b.toString();
  }

  static String _esc(String s) =>
      s.replaceAll('|', '\\|').replaceAll('\n', ' ');
}
