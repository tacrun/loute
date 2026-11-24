// Report engine tests (1-5-5.md §18.1/§15.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:loute/models/report_model.dart';
import 'package:loute/engines/md_engine.dart';
import 'package:loute/engines/sarif_engine.dart';
import 'package:loute/engines/pdf_engine.dart';

ReportPayload sample() => ReportPayload(
      id: 'rep_1',
      actionId: 'recon.subdomain-discovery',
      actionName: 'SUBDOMAIN DISCOVERY',
      moduleName: 'RECON',
      phaseName: 'RECONNAISSANCE',
      status: 'COMPLETED',
      systemVersion: '1.5.5',
      timestamp: DateTime.utc(2025, 1, 1),
      inputs: {
        'catalog_hash': 'abc123',
        'command_preview': 'dnsx -d example.com'
      },
      logs: const [],
      rawOutput: 'www.example.com\nmail.example.com',
      findings: [
        {
          'id': 'CVE-1',
          'title': 'Exposure',
          'severity': 'high',
          'detail': 'open panel',
          'asset': 'example.com'
        },
      ],
    );

void main() {
  test('Markdown engine emits sections and provenance', () {
    final md = MdEngine.render(sample());
    expect(md, contains('# LOUTE Report'));
    expect(md, contains('## Findings'));
    expect(md, contains('## Provenance'));
    expect(md, contains('abc123'));
  });

  test('SARIF engine emits valid 2.1.0 structure', () {
    final sarif = SarifEngine.render(sample());
    expect(sarif, contains('"version": "2.1.0"'));
    expect(sarif, contains('LOUTE'));
    expect(sarif, contains('"level": "error"'));
  });

  test('PDF engine emits a valid PDF header and trailer', () {
    final bytes = PdfEngine.renderBytes(sample());
    final text = String.fromCharCodes(bytes.take(8));
    expect(text, startsWith('%PDF-1.4'));
    expect(String.fromCharCodes(bytes), contains('%%EOF'));
  });
}
