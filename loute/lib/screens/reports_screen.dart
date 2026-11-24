import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/midnight_hacker.dart';
import '../providers/navigation_state.dart';
import '../models/report_model.dart';
import '../services/report_renderer.dart';
import '../services/report_storage.dart';
import '../components/output_viewer.dart';
import '../components/system_alert.dart';
import '../components/terminal_log.dart';
import '../components/green_button.dart';

/// Reports Screen - allows exploration, rendering, and deletion of saved outputs.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportFormat _viewFormat = ReportFormat.html;
  String _content = '';
  List<String> _logLines = [];
  bool _loading = false;
  bool _editing = false;
  final TextEditingController _editor = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    final baseDir = ref.read(navigationProvider).outputSaveLocation;
    final reports = await ReportStorage.listReports(baseDir);
    ref.read(navigationProvider.notifier).setReports(reports);
  }

  Future<void> _selectReport(ReportRecord report) async {
    ref.read(navigationProvider.notifier).selectReport(report);
    setState(() {
      _viewFormat = ReportFormat.html;
      _editing = false;
    });
    await _loadContent(report, ReportFormat.html);
  }

  Future<void> _loadContent(ReportRecord report, ReportFormat format) async {
    setState(() {
      _loading = true;
      _content = '';
      _viewFormat = format;
    });

    try {
      final content = await _ensureFormatAvailable(report, format);
      final logs = await _readLogLines(report.logPath);

      setState(() {
        _content = content ?? '';
        _logLines = logs;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<String?> _ensureFormatAvailable(ReportRecord report, ReportFormat format) async {
    final baseDir = ref.read(navigationProvider).outputSaveLocation;

    if (format == ReportFormat.json || format == ReportFormat.txt || format == ReportFormat.csv || format == ReportFormat.cve) {
      final existing = await ReportStorage.readContent(report, format);
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }

      final payload = await _buildPayloadFromRecord(report);
      if (payload == null) return null;

      if (format == ReportFormat.json) {
        final content = ReportRenderer.renderJson(payload);
        final updated = await ReportStorage.saveJsonReport(
          payload: payload,
          record: report,
          baseDir: baseDir,
          content: content,
        );
        await _refreshReports(updated);
        return content;
      }

      if (format == ReportFormat.txt) {
        final content = ReportRenderer.renderTxt(payload);
        final updated = await ReportStorage.saveTxtReport(
          payload: payload,
          record: report,
          baseDir: baseDir,
          content: content,
        );
        await _refreshReports(updated);
        return content;
      }

      if (format == ReportFormat.csv) {
        final content = ReportRenderer.renderCsv(payload);
        final updated = await ReportStorage.saveCsvReport(
          payload: payload,
          record: report,
          baseDir: baseDir,
          content: content,
        );
        await _refreshReports(updated);
        return content;
      }

      if (format == ReportFormat.cve) {
        final content = ReportRenderer.renderCve(payload);
        final updated = await ReportStorage.saveCveReport(
          payload: payload,
          record: report,
          baseDir: baseDir,
          content: content,
        );
        await _refreshReports(updated);
        return content;
      }
    }

    return ReportStorage.readContent(report, format);
  }

  Future<void> _refreshReports(ReportRecord updated) async {
    final baseDir = ref.read(navigationProvider).outputSaveLocation;
    final reports = await ReportStorage.listReports(baseDir);
    ref.read(navigationProvider.notifier).setReports(reports);
    ref.read(navigationProvider.notifier).selectReport(updated);
  }

  Future<ReportPayload?> _buildPayloadFromRecord(ReportRecord record) async {
    if (record.rawPath == null) return null;
    final rawFile = File(record.rawPath!);
    if (!await rawFile.exists()) return null;

    final rawOutput = await rawFile.readAsString();
    final logs = await _readLogLines(record.logPath);

    return ReportPayload(
      id: record.id,
      actionId: record.actionId,
      actionName: record.actionName,
      moduleName: record.moduleName,
      phaseName: record.phaseName,
      status: record.status,
      systemVersion: ref.read(navigationProvider).systemVersion,
      timestamp: record.timestamp,
      inputs: record.inputs,
      logs: logs,
      rawOutput: rawOutput,
      findings: record.findings,
      supportsCsv: record.supportsCsv,
      supportsCve: record.supportsCve,
    );
  }

  Future<List<String>> _readLogLines(String? logPath) async {
    if (logPath == null || logPath.isEmpty) return [];
    final file = File(logPath);
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    return content.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }

  Future<void> _deleteReport(ReportRecord report) async {
    await ReportStorage.deleteReport(report);
    ref.read(navigationProvider.notifier).deleteReport(report.id);
    setState(() {
      _content = '';
      _logLines = [];
      _editing = false;
    });
  }

  Future<void> _saveEdit(ReportRecord report) async {
    await ReportStorage.editContent(report, _viewFormat, _editor.text);
    setState(() {
      _content = _editor.text;
      _editing = false;
    });
  }

  Color _formatColor(ReportFormat format) {
    return _viewFormat == format ? MidnightHacker.positive : MidnightHacker.dimGreen;
  }

  Widget _buildCodePanel(String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: MidnightHacker.primary, width: 1),
        color: MidnightHacker.background,
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          content.isEmpty ? 'No content available.' : content,
          style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final reports = navState.reports;
    final selectedReport = navState.selectedReport;

    Widget buildSidebar({required bool narrow}) {
      return Container(
        width: narrow ? double.infinity : 320,
        constraints: BoxConstraints(maxHeight: narrow ? 260 : double.infinity),
        decoration: BoxDecoration(
          border: Border(
            right: narrow ? BorderSide.none : MidnightHacker.greenBorder,
            bottom: narrow ? MidnightHacker.greenBorder : BorderSide.none,
          ),
          color: MidnightHacker.panelBg.withOpacity(0.35),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(bottom: MidnightHacker.greenBorder)),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, color: MidnightHacker.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'SAVED REPORTS (${reports.length})',
                      style: MidnightHacker.monoSmall.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: MidnightHacker.dimGreen, size: 18),
                    tooltip: 'Refresh reports',
                    onPressed: _loadReports,
                  ),
                ],
              ),
            ),
            Expanded(
              child: reports.isEmpty
                  ? Center(
                      child: Text(
                        'NO REPORTS FOUND',
                        style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
                      ),
                    )
                  : ListView.builder(
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        final active = selectedReport?.id == report.id;
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: narrow,
                            selected: active,
                            selectedTileColor: MidnightHacker.primary.withOpacity(0.08),
                            title: Text(
                              report.actionName,
                              style: MidnightHacker.monoSmall.copyWith(
                                color: active ? MidnightHacker.positive : MidnightHacker.primary,
                                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${report.status} • ${report.timestamp.toIso8601String()}',
                              style: MidnightHacker.monoSmall.copyWith(fontSize: 10, color: MidnightHacker.dimGreen),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: MidnightHacker.negative, size: 18),
                              tooltip: 'Delete report',
                              onPressed: () async {
                                await _deleteReport(report);
                                SystemAlert.show(
                                  title: 'REPORT DELETED',
                                  message: 'The report has been permanently removed.',
                                  type: AlertType.negative,
                                  context: AlertContext.delete,
                                );
                              },
                            ),
                            onTap: () => _selectReport(report),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    }

    Widget buildContent({required bool narrow}) {
      if (selectedReport == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assessment_outlined, color: MidnightHacker.dimGreen.withOpacity(0.7), size: 52),
                const SizedBox(height: 16),
                Text(
                  'SELECT A REPORT TO EXPLORE DETAILS',
                  style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Run an action from the scan workspace to generate a report.',
                  style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen.withOpacity(0.7), fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      return SingleChildScrollView(
        padding: EdgeInsets.all(narrow ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RUN DATE: ${selectedReport.timestamp.toIso8601String()}', style: MidnightHacker.labelDim),
                      const SizedBox(height: 4),
                      Text(
                        selectedReport.actionName.toUpperCase(),
                        style: MidnightHacker.headingLarge.copyWith(fontSize: narrow ? 22 : 28),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${selectedReport.phaseName} / ${selectedReport.moduleName} • ${selectedReport.status}',
                        style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
                      ),
                    ],
                  ),
                ),
                GreenButton(
                  label: _editing ? 'CANCEL' : 'EDIT',
                  onPressed: () {
                    setState(() {
                      _editing = !_editing;
                      _editor.text = _content;
                    });
                  },
                  borderColor: MidnightHacker.dimGreen,
                  textColor: MidnightHacker.primary,
                ),
                GreenButton(
                  label: 'REFRESH',
                  onPressed: () async {
                    await _loadReports();
                    await _loadContent(selectedReport, _viewFormat);
                  },
                  borderColor: MidnightHacker.dimGreen,
                  textColor: MidnightHacker.primary,
                ),
              ],
            ),
            const Divider(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GreenButton(label: 'HTML', onPressed: () => _loadContent(selectedReport, ReportFormat.html), borderColor: _formatColor(ReportFormat.html), textColor: _formatColor(ReportFormat.html)),
                GreenButton(label: 'JSON', onPressed: () => _loadContent(selectedReport, ReportFormat.json), borderColor: _formatColor(ReportFormat.json), textColor: _formatColor(ReportFormat.json)),
                GreenButton(label: 'TXT', onPressed: () => _loadContent(selectedReport, ReportFormat.txt), borderColor: _formatColor(ReportFormat.txt), textColor: _formatColor(ReportFormat.txt)),
                if (selectedReport.supportsCsv)
                  GreenButton(label: 'CSV', onPressed: () => _loadContent(selectedReport, ReportFormat.csv), borderColor: _formatColor(ReportFormat.csv), textColor: _formatColor(ReportFormat.csv)),
                if (selectedReport.supportsCve)
                  GreenButton(label: 'CVE', onPressed: () => _loadContent(selectedReport, ReportFormat.cve), borderColor: _formatColor(ReportFormat.cve), textColor: _formatColor(ReportFormat.cve)),
              ],
            ),
            const SizedBox(height: 24),
            Text('EXECUTION LOGS', style: MidnightHacker.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(height: 150, child: TerminalLog(lines: _logLines)),
            const SizedBox(height: 24),
            Text('REPORT OUTPUT', style: MidnightHacker.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_loading)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(border: Border.all(color: MidnightHacker.primary, width: 1), color: MidnightHacker.background),
                child: Text('Loading report...', style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen)),
              )
            else if (_editing)
              Container(
                decoration: BoxDecoration(border: Border.all(color: MidnightHacker.primary, width: 1), color: MidnightHacker.background),
                child: TextField(
                  controller: _editor,
                  maxLines: null,
                  style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.primary),
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
                ),
              )
            else
              _viewFormat == ReportFormat.html
                  ? OutputViewer(htmlContent: _content, filePath: selectedReport.htmlPath)
                  : _buildCodePanel(_content),
            if (_editing) ...[
              const SizedBox(height: 16),
              GreenButton(
                label: 'SAVE',
                onPressed: () async => _saveEdit(selectedReport),
                borderColor: MidnightHacker.positive,
                textColor: MidnightHacker.positive,
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: MidnightHacker.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          if (narrow) {
            return Column(
              children: [
                buildSidebar(narrow: true),
                Expanded(child: buildContent(narrow: true)),
              ],
            );
          }
          return Row(
            children: [
              buildSidebar(narrow: false),
              Expanded(child: buildContent(narrow: false)),
            ],
          );
        },
      ),
    );
  }
}
