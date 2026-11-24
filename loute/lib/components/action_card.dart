import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/midnight_hacker.dart';
import '../models/phase_model.dart';
import '../src/rust/api.dart' as api;
import '../providers/navigation_state.dart';
import '../providers/action_session_state.dart';
import '../models/report_model.dart';
import '../services/report_renderer.dart';
import '../services/report_storage.dart';
import '../services/format_export_service.dart';
import '../utils/html_output_parser.dart';
import 'package:file_selector/file_selector.dart';
import 'green_input.dart';
import 'green_button.dart';
import 'progress_bar.dart';
import 'terminal_log.dart';
import 'output_viewer.dart';
import 'system_alert.dart';

/// Action card - displays inputs, execute button, and output for a selected action.
class ActionCard extends ConsumerStatefulWidget {
  final ActionItem action;
  final String moduleName;
  final String phaseName;

  const ActionCard({
    super.key,
    required this.action,
    required this.moduleName,
    required this.phaseName,
  });

  @override
  ConsumerState<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends ConsumerState<ActionCard> {
  final Map<String, TextEditingController> _controllers = {};
  ReportFormat _viewFormat = ReportFormat.html;
  bool _formatBusy = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(ActionCard old) {
    super.didUpdateWidget(old);
    if (old.action.id != widget.action.id) {
      _initControllers();
    }
  }

  void _initControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();

    final sessionMap = ref.read(actionSessionProvider);
    final session = sessionMap[widget.action.id] ?? ActionSession(actionId: widget.action.id);

    final nav = ref.read(navigationProvider);
    for (final input in widget.action.inputs) {
      var initialVal = session.inputs[input.key] ?? input.defaultValue?.toString() ?? '';
      // Wire global settings as smart defaults when user hasn't overridden
      if (session.inputs[input.key] == null) {
        if (input.key == 'concurrency') initialVal = nav.scanConcurrency.toString();
        if (input.key == 'timeout' || input.key == 'timeout_seconds') initialVal = nav.requestTimeoutSeconds.toString();
        if (input.key == 'delay' || input.key == 'delay_ms') initialVal = nav.targetScanDelayMs.toString();
        if (input.key == 'user_agent') initialVal = nav.userAgent;
      }
      _controllers[input.key] = TextEditingController(text: initialVal);
    }
  }

  Future<void> _switchFormat(ReportFormat format) async {
    setState(() {
      _viewFormat = format;
    });

    if (format == ReportFormat.html) return;
    await _ensureFormatGenerated(format);
  }

  Future<void> _ensureFormatGenerated(ReportFormat format) async {
    if (_formatBusy) return;
    final session = ref.read(actionSessionProvider)[widget.action.id];
    if (session == null || session.reportPayload == null || session.report == null) {
      return;
    }

    if (format == ReportFormat.json && session.jsonOutput != null) return;
    if (format == ReportFormat.txt && session.txtOutput != null) return;

    setState(() {
      _formatBusy = true;
    });

    try {
      final payload = session.reportPayload!;
      final record = session.report!;
      final baseDir = ref.read(navigationProvider).outputSaveLocation;

      if (format == ReportFormat.json) {
        final content = ReportRenderer.renderJson(payload);
        final updated = await ReportStorage.saveJsonReport(
          payload: payload,
          record: record,
          baseDir: baseDir,
          content: content,
        );
        ref.read(actionSessionProvider.notifier).updateReportFormats(
          widget.action.id,
          report: updated,
          jsonOutput: content,
        );
        ref.read(navigationProvider.notifier).setReports(
          await ReportStorage.listReports(baseDir),
        );
      }

      if (format == ReportFormat.txt) {
        final content = ReportRenderer.renderTxt(payload);
        final updated = await ReportStorage.saveTxtReport(
          payload: payload,
          record: record,
          baseDir: baseDir,
          content: content,
        );
        ref.read(actionSessionProvider.notifier).updateReportFormats(
          widget.action.id,
          report: updated,
          txtOutput: content,
        );
        ref.read(navigationProvider.notifier).setReports(
          await ReportStorage.listReports(baseDir),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _formatBusy = false;
        });
      }
    }
  }

  Future<void> _execute() async {
    final notifier = ref.read(actionSessionProvider.notifier);
    final currentSession = ref.read(actionSessionProvider)[widget.action.id];

    if (currentSession != null && currentSession.status == ActionStatus.running) {
      notifier.stopAction(widget.action.id);
      return;
    }

    // Frontend Input Validation
    for (final input in widget.action.inputs) {
      final val = _controllers[input.key]?.text.trim() ?? '';
      final isOptional = input.key == 'wordlist_path' || input.key == 'nameserver';
      
      if (val.isEmpty) {
        if (!isOptional) {
          SystemAlert.show(
            title: 'VALIDATION ERROR',
            message: '${input.label.toUpperCase()} cannot be empty.',
            type: AlertType.negative,
            context: AlertContext.inputInvalid,
          );
          return;
        }
        continue;
      }

      // Regex validations
      bool isValid = true;
      String errorMsg = '';

      if (input.key == 'domain' || input.key == 'target' || input.key == 'target_url' || (input.key == 'nameserver' && val.isNotEmpty)) {
        final domainRegex = RegExp(r"^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", caseSensitive: false);
        final cleanVal = val.replaceAll(RegExp(r'^https?://'), '').split('/')[0];
        if (!domainRegex.hasMatch(cleanVal)) {
          isValid = false;
          errorMsg = 'Must be a valid FQDN (e.g. example.com)';
        }
      } else if (input.key == 'target_ip') {
        final ipRegex = RegExp(r"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$");
        if (!ipRegex.hasMatch(val)) {
          isValid = false;
          errorMsg = 'Must be a valid IPv4 address';
        }
      } else if (input.key == 'cidr') {
        final cidrParts = val.split('/');
        if (cidrParts.length != 2) {
          isValid = false;
          errorMsg = 'Must be in format IP/PREFIX (e.g. 192.168.1.0/24)';
        } else {
          final ipRegex = RegExp(r"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$");
          final prefix = int.tryParse(cidrParts[1]);
          if (!ipRegex.hasMatch(cidrParts[0]) || prefix == null || prefix < 0 || prefix > 32) {
            isValid = false;
            errorMsg = 'Invalid IP or CIDR prefix length';
          }
        }
      } else if (input.key == 'bucket_name') {
        final s3Regex = RegExp(r"^[a-z0-9.-]+$");
        if (!s3Regex.hasMatch(val) || val.length < 3 || val.length > 63 || val.contains('..')) {
          isValid = false;
          errorMsg = 'Must be 3-63 chars, lowercase alphanumeric or hyphens';
        }
      } else if (input.key == 'project_id') {
        final fbRegex = RegExp(r"^[a-z0-9-]+$");
        if (!fbRegex.hasMatch(val)) {
          isValid = false;
          errorMsg = 'Must contain only lowercase letters, numbers, and hyphens';
        }
      }

      if (!isValid) {
        SystemAlert.show(
          title: 'INVALID FORMAT',
          message: '${input.label.toUpperCase()}: $errorMsg',
          type: AlertType.negative,
          context: AlertContext.inputInvalid,
        );
        return;
      }
    }

    final nav = ref.read(navigationProvider);
    notifier.startAction(widget.action.id, '[${_timestamp()}] Initializing action: ${widget.action.name}...');
    notifier.addLog(
      widget.action.id,
      '[${_timestamp()}] Config: concurrency=${nav.scanConcurrency} timeout=${nav.requestTimeoutSeconds}s delay=${nav.targetScanDelayMs}ms proxy=${nav.enableProxy ? nav.proxyAddress : "off"} sslVerify=${!nav.disableSslValidation}',
      progress: 0.1,
    );

    try {
      final rustFunc = widget.action.rustFunction;
      String result;

      notifier.addLog(widget.action.id, '[${_timestamp()}] Sending request to native Rust core...', progress: 0.4);

      if (rustFunc == 'dns_bruteforce') {
        final domain = _controllers['domain']?.text ?? '';
        final wordlist = _controllers['wordlist_path']?.text;
        final concurrency = int.tryParse(_controllers['concurrency']?.text ?? '20') ?? 20;
        result = await api.dnsBruteforce(
          domain: domain,
          wordlistPath: wordlist?.isEmpty == true ? null : wordlist,
          concurrency: BigInt.from(concurrency),
        );
      } else if (rustFunc == 'ct_logs') {
        final domain = _controllers['domain']?.text ?? '';
        result = await api.ctLogs(domain: domain);
      } else if (rustFunc == 'zone_transfer') {
        final domain = _controllers['domain']?.text ?? '';
        final ns = _controllers['nameserver']?.text;
        result = await api.zoneTransfer(
          domain: domain,
          nameserver: ns?.isEmpty == true ? null : ns,
        );
      } else if (rustFunc == 'reverse_dns') {
        final cidr = _controllers['cidr']?.text ?? '';
        result = await api.reverseDns(cidr: cidr);
      } else if (rustFunc == 'wildcard_detect') {
        final domain = _controllers['domain']?.text ?? '';
        result = await api.wildcardDetect(domain: domain);
      } else if (rustFunc == 'cloud_provider') {
        final target = _controllers['target']?.text ?? '';
        result = await api.cloudProvider(target: target);
      } else if (rustFunc == 's3_check') {
        final bucket = _controllers['bucket_name']?.text ?? '';
        result = await api.s3Check(bucketName: bucket);
      } else if (rustFunc == 'metadata_probe') {
        final ip = _controllers['target_ip']?.text ?? '';
        result = await api.metadataProbe(targetIp: ip);
      } else if (rustFunc == 'firebase_check') {
        final project = _controllers['project_id']?.text ?? '';
        result = await api.firebaseCheck(projectId: project);
      } else if (rustFunc == 'cdn_detect') {
        final url = _controllers['target_url']?.text ?? '';
        result = await api.cdnDetect(targetUrl: url);
      } else if (rustFunc == 'network_services_audit') {
        result = await api.networkServicesAudit();
      } else {
        result = await api.runStubAction(actionId: widget.action.id);
      }

      final endLog = '[${_timestamp()}] Native core execution finished.';
      final sessionSnapshot = ref.read(actionSessionProvider)[widget.action.id];
      final logs = [...(sessionSnapshot?.logs ?? []), endLog];

      final reportId = ReportStorage.createReportId();
      final now = DateTime.now();
      final supportsCve = RegExp(r'CVE-\\d{4}-\\d{4,7}', caseSensitive: false).hasMatch(result);
      final supportsCsv = widget.action.outputType == 'table' || result.contains('<table');

      // Parse HTML output to extract findings
      notifier.addLog(widget.action.id, '[${_timestamp()}] Parsing results and extracting findings...', progress: 0.6);
      final parsedFindings = HtmlOutputParser.parseActionOutput(result, widget.action.name);
      notifier.addLog(widget.action.id, '[${_timestamp()}] Extracted ${parsedFindings.length} findings', progress: 0.7);

      final payload = ReportPayload(
        id: reportId,
        actionId: widget.action.id,
        actionName: widget.action.name,
        moduleName: widget.moduleName,
        phaseName: widget.phaseName,
        status: 'SUCCESS',
        systemVersion: ref.read(navigationProvider).systemVersion,
        timestamp: now,
        inputs: Map<String, String>.from(sessionSnapshot?.inputs ?? {}),
        logs: <String>[...(sessionSnapshot?.logs ?? []).cast<String>(), endLog],
        rawOutput: result,
        findings: parsedFindings,
        supportsCsv: supportsCsv,
        supportsCve: supportsCve,
      );

      notifier.addLog(widget.action.id, '[${_timestamp()}] Rendering HTML report...', progress: 0.75);
      final reportHtml = await ReportRenderer.renderHtml(payload);
      final baseDir = ref.read(navigationProvider).outputSaveLocation;
      final reportRecord = await ReportStorage.saveHtmlReport(
        payload: payload,
        baseDir: baseDir,
        htmlContent: reportHtml,
      );
      
      notifier.addLog(widget.action.id, '[${_timestamp()}] Skipping auto-generation', progress: 0.85);

      notifier.addLog(widget.action.id, '[${_timestamp()}] Action completed successfully', progress: 1.0);

      notifier.finishAction(
        widget.action.id,
        reportHtml,
        endLog,
        report: reportRecord,
        reportPayload: payload,
      );

      ref.read(navigationProvider.notifier).addReport(reportRecord);
      if (mounted) {
        setState(() {
          _viewFormat = ReportFormat.html;
        });
      }
    } catch (e) {
      final errorLog = '[${_timestamp()}] ERROR: Native call failed: $e';
      final errorHtml = "<div style='color: #FF3B30;'>Fatal execution error: $e</div>";
      final sessionSnapshot = ref.read(actionSessionProvider)[widget.action.id];
      final logs = <String>[...(sessionSnapshot?.logs ?? []).cast<String>(), errorLog];

      final reportId = ReportStorage.createReportId();
      final now = DateTime.now();
      final payload = ReportPayload(
        id: reportId,
        actionId: widget.action.id,
        actionName: widget.action.name,
        moduleName: widget.moduleName,
        phaseName: widget.phaseName,
        status: 'FAILED',
        systemVersion: ref.read(navigationProvider).systemVersion,
        timestamp: now,
        inputs: Map<String, String>.from(sessionSnapshot?.inputs ?? {}),
        logs: logs,
        rawOutput: errorHtml,
        findings: const [],
        supportsCsv: false,
        supportsCve: false,
      );

      try {
        final reportHtml = await ReportRenderer.renderHtml(payload);
        final baseDir = ref.read(navigationProvider).outputSaveLocation;
        final reportRecord = await ReportStorage.saveHtmlReport(
          payload: payload,
          baseDir: baseDir,
          htmlContent: reportHtml,
        );
        
        notifier.addLog(widget.action.id, '[${_timestamp()}] Skipping auto-generation');

        notifier.failAction(
          widget.action.id,
          errorLog,
          reportHtml,
          report: reportRecord,
          reportPayload: payload,
        );

        ref.read(navigationProvider.notifier).addReport(reportRecord);
      } catch (_) {
        notifier.failAction(widget.action.id, errorLog, errorHtml);
      }
    }
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Color _formatColor(ReportFormat format) {
    return _viewFormat == format ? MidnightHacker.positive : MidnightHacker.dimGreen;
  }

  Widget _buildCodePanel(String content) {
    return Container(
      height: 420,
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
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPlatform = Platform.isLinux
        ? 'linux'
        : Platform.isWindows
            ? 'windows'
            : Platform.isAndroid
                ? 'android'
                : 'generic';

    final isPlatformSupported = widget.action.supportedPlatforms == null ||
        widget.action.supportedPlatforms!.contains(currentPlatform);

    final sessionMap = ref.watch(actionSessionProvider);
    final session = sessionMap[widget.action.id] ?? ActionSession(actionId: widget.action.id);

    final isRunning = session.status == ActionStatus.running;
    final isStopped = session.status == ActionStatus.stopped;

    Color buttonColor;
    String buttonText;
    IconData buttonIcon;

    if (isRunning) {
      buttonColor = Colors.amber;
      buttonText = 'RUNNING';
      buttonIcon = Icons.hourglass_empty_outlined;
    } else if (isStopped) {
      buttonColor = Colors.red;
      buttonText = 'STOPPED';
      buttonIcon = Icons.pause_circle_outline;
    } else {
      buttonColor = isPlatformSupported ? MidnightHacker.primary : MidnightHacker.dimGreen.withOpacity(0.3);
      buttonText = 'EXECUTE ACTION';
      buttonIcon = Icons.play_arrow_outlined;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Centered Header ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('${widget.phaseName.toUpperCase()}  /  ${widget.moduleName.toUpperCase()}',
                  style: MidnightHacker.labelDim.copyWith(letterSpacing: 3)),
              const SizedBox(height: 12),
              Text(widget.action.name.toUpperCase(),
                  style: MidnightHacker.heading.copyWith(fontSize: 28, letterSpacing: 2)),
              const SizedBox(height: 6),
              Text(
                'FUNCTION: ${widget.action.rustFunction}   |   STYLE: ${widget.action.executionStyle}',
                style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Description Box ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MidnightHacker.background,
              border: Border.all(color: MidnightHacker.dimGreen, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: MidnightHacker.dimGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.action.description,
                    style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.primary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Main Execution Grid ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 800;
              final leftColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: MidnightHacker.primary, width: 1),
                        color: MidnightHacker.panelBg.withOpacity(0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('INPUT PARAMETERS', style: MidnightHacker.label.copyWith(letterSpacing: 2, fontSize: 12)),
                          const SizedBox(height: 16),
                          if (widget.action.inputs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text('No inputs required for this action.', style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen)),
                            )
                          else
                            ...widget.action.inputs.map((input) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: GreenInput(
                                  label: input.label,
                                  hint: input.hint,
                                  controller: _controllers[input.key],
                                  keyboardType: input.type == InputFieldType.number
                                      ? TextInputType.number
                                      : TextInputType.text,
                                  onChanged: (val) {
                                    ref.read(actionSessionProvider.notifier).updateInput(widget.action.id, input.key, val);
                                  },
                                  onSubmitted: (_) {
                                    if (isPlatformSupported && !isRunning) {
                                      _execute();
                                    }
                                  },
                                ),
                              );
                            }),

                          if (!isPlatformSupported) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red, width: 1),
                                color: Colors.red.withOpacity(0.05),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_outlined, color: Colors.red, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'ACTION INCOMPATIBLE WITH HOST OS: ${currentPlatform.toUpperCase()}\n'
                                      'Supported: ${widget.action.supportedPlatforms!.join(", ").toUpperCase()}',
                                      style: MidnightHacker.monoSmall.copyWith(color: Colors.red, fontWeight: FontWeight.bold, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          Column(
                            children: [
                              GreenButton(
                                label: buttonText,
                                onPressed: !isPlatformSupported ? null : _execute,
                                icon: isRunning ? null : buttonIcon,
                                expanded: true,
                                isFilled: isRunning || isStopped,
                                isLoading: isRunning,
                                borderColor: buttonColor,
                                textColor: isRunning || isStopped ? MidnightHacker.background : buttonColor,
                              ),
                              if (session.output != null) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 40,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        GreenButton(
                                          label: _formatBusy && _viewFormat == ReportFormat.json ? 'JSON...' : 'JSON',
                                          onPressed: _formatBusy
                                              ? null
                                              : () => _switchFormat(ReportFormat.json),
                                          borderColor: _formatColor(ReportFormat.json),
                                          textColor: _formatColor(ReportFormat.json),
                                        ),
                                        const SizedBox(width: 8),
                                        GreenButton(
                                          label: _formatBusy && _viewFormat == ReportFormat.txt ? 'TXT...' : 'TXT',
                                          onPressed: _formatBusy
                                              ? null
                                              : () => _switchFormat(ReportFormat.txt),
                                          borderColor: _formatColor(ReportFormat.txt),
                                          textColor: _formatColor(ReportFormat.txt),
                                        ),
                                        const SizedBox(width: 8),
                                        GreenButton(
                                          label: 'HTML',
                                          onPressed: _formatBusy
                                              ? null
                                              : () => _switchFormat(ReportFormat.html),
                                          borderColor: _formatColor(ReportFormat.html),
                                          textColor: _formatColor(ReportFormat.html),
                                        ),
                                        const SizedBox(width: 8),
                                        GreenButton(
                                          label: 'DOWNLOAD',
                                          onPressed: () async {
                                            if (session.report != null && session.reportPayload != null) {
                                              try {
                                                final ext = _viewFormat.name;
                                                final now = DateTime.now();
                                                final timeStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
                                                final fileName = 'loute_recon_${widget.action.name.toLowerCase().replaceAll(' ', '_')}_$timeStr.$ext';
                                                
                                                final FileSaveLocation? location = await getSaveLocation(suggestedName: fileName);
                                                
                                                if (location != null) {
                                                  String contentToSave = '';
                                                  if (_viewFormat == ReportFormat.html) {
                                                    contentToSave = session.output ?? '';
                                                  } else if (_viewFormat == ReportFormat.json) {
                                                    contentToSave = session.jsonOutput ?? ReportRenderer.renderJson(session.reportPayload!);
                                                  } else if (_viewFormat == ReportFormat.txt) {
                                                    contentToSave = session.txtOutput ?? ReportRenderer.renderTxt(session.reportPayload!);
                                                  }

                                                  final file = File(location.path);
                                                  await file.writeAsString(contentToSave);

                                                  SystemAlert.show(
                                                    title: 'FILE DOWNLOADED',
                                                    message: 'Saved to ${location.path}',
                                                    type: AlertType.positive,
                                                    context: AlertContext.download,
                                                  );
                                                }
                                              } catch (e) {
                                                SystemAlert.show(
                                                  title: 'DOWNLOAD ERROR',
                                                  message: 'Failed to download file: $e',
                                                  type: AlertType.negative,
                                                  context: AlertContext.error,
                                                );
                                              }
                                            }
                                          },
                                          icon: Icons.download_outlined,
                                          borderColor: MidnightHacker.primary,
                                          textColor: MidnightHacker.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Logs Box
                    Text('EXECUTION LOG', style: MidnightHacker.label.copyWith(letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      child: session.logs.isNotEmpty
                          ? TerminalLog(lines: session.logs)
                          : Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: MidnightHacker.dimGreen.withOpacity(0.2)),
                                color: MidnightHacker.panelBg.withOpacity(0.3),
                              ),
                              child: Center(
                                child: Text('Terminal standby...', style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen)),
                              ),
                            ),
                    ),
                  ],
              );

              final rightColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('OUTPUT', style: MidnightHacker.label.copyWith(letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 12),
                    if (isRunning || session.progress > 0) ...[
                      ProgressBar(value: session.progress),
                      const SizedBox(height: 16),
                    ],
                    if (session.output != null)
                      _viewFormat == ReportFormat.html
                          ? OutputViewer(htmlContent: session.output!, filePath: session.report?.htmlPath)
                          : _viewFormat == ReportFormat.json
                              ? _buildCodePanel(session.jsonOutput ?? 'Generating JSON output...')
                              : _viewFormat == ReportFormat.txt
                                  ? _buildCodePanel(session.txtOutput ?? 'Generating TXT output...')
                                  : OutputViewer(htmlContent: session.output!, filePath: session.report?.htmlPath)
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: MidnightHacker.dimGreen.withOpacity(0.2)),
                          color: MidnightHacker.panelBg.withOpacity(0.3),
                        ),
                        child: Center(
                          child: Text('Awaiting execution...', style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen)),
                        ),
                      ),
                  ],
              );

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: leftColumn),
                    const SizedBox(width: 32),
                    Expanded(flex: 1, child: rightColumn),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftColumn,
                    const SizedBox(height: 32),
                    rightColumn,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
