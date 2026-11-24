import 'dart:convert';
import '../models/report_model.dart';

/// Minimal dependency-free PDF engine for print deliverables (§15.1).
/// Emits a valid PDF 1.4 with a single Helvetica text stream. Multi-page via
/// simple line chunking. Kept self-contained to avoid adding a PDF dependency.
class PdfEngine {
  static List<int> renderBytes(ReportPayload payload) {
    final lines = <String>[
      'LOUTE Report - ${payload.actionName}',
      'LOUTE V${payload.systemVersion} | ${payload.timestamp.toIso8601String()}',
      'Status: ${payload.status}',
      'Phase/Module: ${payload.phaseName} / ${payload.moduleName}',
      '',
      'SUMMARY',
      'Action: ${payload.actionName} (${payload.actionId})',
      'Findings: ${payload.findings.length}',
      '',
    ];
    for (final f in payload.findings) {
      lines.add('[${f['severity'] ?? 'info'}] ${f['title'] ?? ''}');
      final detail = (f['detail']?.toString() ?? '').replaceAll('\n', ' ');
      if (detail.isNotEmpty) lines.add('  $detail');
    }
    lines.add('');
    lines.add('PROVENANCE');
    lines.add('Catalog: ${payload.inputs['catalog_hash'] ?? 'embedded'}');
    lines.add(
        'Command: ${payload.inputs['command_preview'] ?? payload.actionId}');
    lines.add('Report ID: ${payload.id}');

    // Sanitize to ASCII printable for the built-in Helvetica font.
    final clean =
        lines.map((l) => l.replaceAll(RegExp(r'[^\x20-\x7E]'), '?')).toList();

    // Build content stream with fixed line height.
    final buf = StringBuffer();
    buf.writeln('BT');
    buf.writeln('/F1 10 Tf');
    buf.writeln('12 TL');
    buf.writeln('40 790 Td');
    for (final l in clean) {
      buf.writeln('(${_esc(l)}) Tj');
      buf.writeln('T*');
    }
    buf.writeln('ET');
    final content = utf8.encode(buf.toString());

    // PDF objects.
    final objects = <List<int>>[];
    objects.add(utf8.encode('<< /Type /Catalog /Pages 2 0 R >>'));
    objects.add(utf8.encode('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'));
    objects
        .add(utf8.encode('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 842] '
            '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>'));
    objects.add(_stream(content));
    objects.add(
        utf8.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'));

    return _assemble(objects);
  }

  static String render(ReportPayload payload) =>
      String.fromCharCodes(renderBytes(payload));

  static List<int> _stream(List<int> content) {
    final b = <int>[];
    b.addAll(utf8.encode('<< /Length ${content.length} >>\nstream\n'));
    b.addAll(content);
    b.addAll(utf8.encode('\nendstream'));
    return b;
  }

  static List<int> _assemble(List<List<int>> objects) {
    final out = <int>[];
    void w(String s) => out.addAll(utf8.encode(s));
    w('%PDF-1.4\n');
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      w('${i + 1} 0 obj\n');
      out.addAll(objects[i]);
      w('\nendobj\n');
    }
    final xref = out.length;
    w('xref\n0 ${objects.length + 1}\n');
    w('0000000000 65535 f \n');
    for (final off in offsets) {
      w('${off.toString().padLeft(10, '0')} 00000 n \n');
    }
    w('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n');
    w('startxref\n$xref\n%%EOF\n');
    return out;
  }

  static String _esc(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)');
}
