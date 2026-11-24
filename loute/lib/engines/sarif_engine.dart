import 'dart:convert';
import '../models/report_model.dart';

/// SARIF 2.1.0 engine for CI integration (1-5-5.md §15.1).
class SarifEngine {
  static String render(ReportPayload payload) {
    final rules = <Map<String, dynamic>>[];
    final results = <Map<String, dynamic>>[];

    final seen = <String>{};
    for (final f in payload.findings) {
      final id = f['id']?.toString() ?? f['title']?.toString() ?? 'LOUTE001';
      if (seen.add(id)) {
        rules.add({
          'id': id,
          'name': f['title']?.toString() ?? id,
          'shortDescription': {'text': f['title']?.toString() ?? id},
        });
      }
      final level = _level(f['severity']?.toString());
      results.add({
        'ruleId': id,
        'level': level,
        'message': {
          'text': f['detail']?.toString() ?? f['title']?.toString() ?? 'Finding'
        },
        'locations': [
          {
            'physicalLocation': {
              'artifactLocation': {
                'uri': f['asset']?.toString() ?? payload.actionId
              },
            }
          }
        ],
      });
    }

    final sarif = {
      r'$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
      'version': '2.1.0',
      'runs': [
        {
          'tool': {
            'driver': {
              'name': 'LOUTE',
              'version': payload.systemVersion,
              'rules': rules,
            }
          },
          'results': results,
          'properties': {
            'catalog_hash': payload.inputs['catalog_hash'] ?? 'embedded',
            'report_id': payload.id,
          },
        }
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(sarif);
  }

  static String _level(String? sev) {
    switch (sev?.toLowerCase()) {
      case 'critical':
      case 'high':
        return 'error';
      case 'medium':
        return 'warning';
      default:
        return 'note';
    }
  }
}
