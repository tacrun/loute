// capability_screen.dart - Operator screen for a single catalog capability.
// Three full-width stacked sections: input parameters, execution log, output.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../themes/midnight_hacker.dart';
import '../../models/catalog_ui.dart';
import '../../generated/capability_index.dart';
import '../../generated/wordlist_index.dart';
import '../../providers/navigation_state.dart';
import '../../src/rust/api.dart' as rust;

class CapabilityScreen extends ConsumerStatefulWidget {
  const CapabilityScreen({super.key});

  @override
  ConsumerState<CapabilityScreen> createState() => _CapabilityScreenState();
}

class _CapabilityScreenState extends ConsumerState<CapabilityScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _wordlistSelections = {};
  final List<String> _log = [];
  final ScrollController _logScroll = ScrollController();

  String? _capabilityId;
  List<ActionGroup> _groups = const [];
  String? _groupId;
  int _operationIndex = 0;
  List<OperationMetaView> _operations = const [];

  String _outputRaw = '';
  List<dynamic> _findings = const [];
  List<dynamic> _assets = const [];
  String _commandPreview = '';
  String _status = 'IDLE';
  int _outputTab = 0;
  bool _running = false;
  bool _runtimeReady = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _logScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ensureRuntime();
  }

  Future<void> _ensureRuntime() async {
    try {
      await rust.initRuntime();
      if (mounted) setState(() => _runtimeReady = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Runtime init failed: $e');
    }
  }

  void _syncCapability(CapabilityEntry cap) {
    if (_capabilityId == cap.id) return;
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _wordlistSelections.clear();
    for (final input in cap.inputs) {
      _controllers[input.key] = TextEditingController(text: input.defaultValue);
    }
    _groups = CatalogUi.actionGroups(cap);
    setState(() {
      _capabilityId = cap.id;
      _groupId = _groups.isNotEmpty ? _groups.first.id : null;
      _operationIndex = 0;
      _operations = const [];
      _outputRaw = '';
      _findings = const [];
      _assets = const [];
      _commandPreview = '';
      _status = 'IDLE';
      _error = null;
      _log.clear();
    });
    _loadOperations(cap.id);
  }

  Future<void> _loadOperations(String id) async {
    try {
      final raw = await rust.listOperations(id: id);
      final parsed = jsonDecode(raw);
      if (!mounted || parsed is! List) return;
      final ops = parsed
          .map((o) => OperationMetaView(
                index: (o['index'] ?? 0) as int,
                name: (o['name'] ?? 'Run').toString(),
                binary: (o['binary'] ?? 'native').toString(),
                output: (o['output'] ?? 'lines').toString(),
                stage: (o['stage'] ?? 1) as int,
                probe: (o['probe'] ?? false) as bool,
              ))
          .toList();
      if (mounted) setState(() => _operations = ops);
    } catch (_) {}
  }

  List<OperationMetaView> get _visibleOperations {
    if (_groupId == null) return _operations;
    ActionGroup? group;
    for (final g in _groups) {
      if (g.id == _groupId) {
        group = g;
        break;
      }
    }
    if (group == null) return _operations;
    final names = group.operations.map((o) => o.name).toSet();
    return _operations.where((o) => names.contains(o.name)).toList();
  }

  Map<String, String> _collectInputs() {
    final data = <String, String>{};
    for (final entry in _controllers.entries) {
      data[entry.key] = entry.value.text.trim();
    }
    final wordlist = _wordlistSelections.values.where((s) => s.isNotEmpty).toList();
    if (wordlist.isNotEmpty) {
      data['wordlist'] = wordlist.first;
    }
    return data;
  }

  void _pushLog(String line) {
    setState(() {
      _log.add(line);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(
          _logScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _execute(CapabilityEntry cap) async {
    if (_running) return;
    final visible = _visibleOperations;
    if (visible.isEmpty) {
      setState(() => _error = 'No sub-actions available for this capability.');
      return;
    }
    final op = visible[_operationIndex.clamp(0, visible.length - 1)];
    final inputs = _collectInputs();

    setState(() {
      _running = true;
      _error = null;
      _log.clear();
      _status = 'PLANNING';
      _outputTab = 0;
    });

    try {
      _pushLog('Capability: ${cap.id}');
      _pushLog('Sub-action [${op.index}]: ${op.name}');
      _pushLog('Provider: ${op.binary}');

      final inputsJson = jsonEncode(inputs);
      final dry = await rust.dryRunOperation(
        id: cap.id,
        operationIndex: op.index,
        inputs: inputsJson,
      );
      final plan = jsonDecode(dry);
      if (plan is Map && plan['error'] != null) {
        throw Exception(plan['error'].toString());
      }
      _commandPreview = (plan is Map ? plan['command_preview'] : '').toString();
      _pushLog('Command: $_commandPreview');
      setState(() => _status = 'RUNNING');

      final raw = await rust.runOperation(
        id: cap.id,
        operationIndex: op.index,
        inputs: inputsJson,
      );
      final result = jsonDecode(raw);
      if (result is Map && result['error'] != null) {
        throw Exception(result['error'].toString());
      }

      final exec = (result is Map ? result['result'] : {}) as Map;
      final stdout = (exec['stdout'] ?? '').toString();
      final stderr = (exec['stderr'] ?? '').toString();
      final exitCode = (exec['exit_code'] ?? 0).toString();
      final status = (exec['status'] ?? 'completed').toString();
      final duration = (exec['duration_secs'] ?? 0).toString();

      final stats = (result is Map ? result['parse_stats'] : {}) as Map;
      if (stdout.isNotEmpty) {
        for (final line in stdout.split('\n')) {
          if (line.trim().isNotEmpty) _pushLog(line.trim());
        }
      }
      if (stderr.isNotEmpty) {
        _pushLog('stderr: $stderr');
      }

      setState(() {
        _outputRaw = stdout;
        _status = status.toUpperCase();
        _commandPreview = (exec['command_preview'] ?? _commandPreview).toString();
      });

      try {
        final parsedOut = jsonDecode(stdout);
        if (parsedOut is List) {
          _findings = parsedOut;
          _assets = const [];
        } else if (parsedOut is Map) {
          _findings = parsedOut['findings'] is List ? parsedOut['findings'] : const [];
          _assets = parsedOut['assets'] is List ? parsedOut['assets'] : const [];
        }
      } catch (_) {
        _findings = const [];
        _assets = const [];
      }

      _pushLog('Exit: $exitCode | Duration: ${duration}s');
      _pushLog('Parsed assets: ${stats['assets'] ?? 0} | findings: ${stats['findings'] ?? 0}');
      _pushLog('Status: ${_status.toLowerCase()}');
    } catch (e) {
      setState(() => _error = e.toString());
      _pushLog('ERROR: $e');
      setState(() => _status = 'FAILED');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cap = ref.watch(navigationProvider).currentCapability;
    if (cap == null) {
      return Center(
        child: Text('Select a capability from the sidebar to begin.',
            style: MidnightHacker.labelDim),
      );
    }

    _syncCapability(cap);
    final phase = CatalogUi.phaseFor(cap);
    final groups = _groups;
    if (_groupId == null && groups.isNotEmpty) _groupId = groups.first.id;
    final visibleOps = _visibleOperations;
    if (_operationIndex >= visibleOps.length && visibleOps.isNotEmpty) {
      _operationIndex = 0;
    }

    return Scaffold(
      backgroundColor: MidnightHacker.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(cap, phase),
                const SizedBox(height: 14),
                _buildActionSelector(cap),
                const SizedBox(height: 18),
                _Section(
                  index: '01',
                  title: 'INPUT PARAMETERS',
                  child: _buildInputs(cap),
                ),
                const SizedBox(height: 18),
                _Section(
                  index: '02',
                  title: 'EXECUTION LOG',
                  child: _buildLog(),
                ),
                const SizedBox(height: 18),
                _Section(
                  index: '03',
                  title: 'OUTPUT',
                  child: _buildOutput(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CapabilityEntry cap, PhaseInfo phase) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CatalogUi.iconFor(cap), color: MidnightHacker.primary, size: 26),
            const SizedBox(width: 12),
            Text(cap.label,
                style: MidnightHacker.headingLarge.copyWith(fontSize: 24)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${phase.name}  /  ${cap.id}',
          style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          cap.summary,
          style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            _Badge('RISK ${cap.risk.toUpperCase()}', MidnightHacker.positive),
            _Badge('NOISE ${cap.noise.toUpperCase()}', MidnightHacker.primary),
            _Badge('${cap.operations.length} SUB-ACTIONS', MidnightHacker.primary),
            _Badge('STATUS $_status', _status == 'FAILED'
                ? MidnightHacker.negative
                : MidnightHacker.positive),
          ],
        ),
        if (cap.chains.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Chains into: ${cap.chains.join(', ')}',
              style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildActionSelector(CapabilityEntry cap) {
    final visibleOps = _visibleOperations;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: MidnightHacker.dimGreen)),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _groups.map((g) {
              final active = g.id == _groupId;
              return _ChipButton(
                label: g.name,
                icon: g.icon,
                active: active,
                onTap: () {
                  setState(() {
                    _groupId = g.id;
                    _operationIndex = 0;
                  });
                  ref.read(navigationProvider.notifier).selectGroup(g.id);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: List.generate(visibleOps.length, (i) {
              final op = visibleOps[i];
              return _ChipButton(
                label: '${op.name}  ·  ${op.binary}',
                icon: Icons.chevron_right_outlined,
                active: i == _operationIndex,
                compact: true,
                onTap: () => setState(() => _operationIndex = i),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInputs(CapabilityEntry cap) {
    final inputs = cap.inputs;
    return Column(
      children: [
        if (inputs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('This capability requires no input parameters.',
                style: MidnightHacker.labelDim),
          ),
        ...inputs.map((input) => _buildInputField(cap, input)),
        const SizedBox(height: 14),
        SizedBox(
          width: 220,
          child: GreenExecuteButton(
            running: _running,
            onTap: () => _execute(cap),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.negative), textAlign: TextAlign.center),
        ],
        if (_commandPreview.isNotEmpty) ...[
          const SizedBox(height: 10),
          SelectableText(
            _commandPreview,
            style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildInputField(CapabilityEntry cap, CapInputDef input) {
    final hint = CatalogUi.wordlistHint(input, cap);
    final controller = _controllers[input.key] ??
        (_controllers[input.key] = TextEditingController(text: input.defaultValue));
    final label = input.key.replaceAll('_', ' ').toUpperCase();

    if (hint != null) {
      final options = wordlistsForCategory(hint.category);
      final selected = _wordlistSelections.putIfAbsent(input.key, () => '');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DropdownButtonFormField<String>(
          value: selected,
          dropdownColor: MidnightHacker.panelBg,
          decoration: InputDecoration(
            labelText: '$label (${hint.label})',
            border: MidnightHacker.inputBorder(),
          ),
          style: MidnightHacker.monoSmall,
          items: [
            const DropdownMenuItem<String>(value: '', child: Text('Use catalog default')),
            ...options.map((w) => DropdownMenuItem<String>(
                  value: w.id,
                  child: Text(w.label),
                )),
          ],
          onChanged: (v) => setState(() => _wordlistSelections[input.key] = v ?? ''),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        style: MidnightHacker.monoSmall,
        decoration: InputDecoration(
          labelText: label + (input.required ? ' *' : ''),
          hintText: input.help.isNotEmpty ? input.help : input.key,
          border: MidnightHacker.inputBorder(),
        ),
      ),
    );
  }

  Widget _buildLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_log.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('No execution log yet. Press Execute to begin.',
                style: MidnightHacker.labelDim, textAlign: TextAlign.center),
          )
        else
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: MidnightHacker.primary)),
            child: ListView.builder(
              controller: _logScroll,
              itemCount: _log.length,
              itemBuilder: (context, i) => Text(
                '> ${_log[i]}',
                style: MidnightHacker.monoSmall.copyWith(
                  color: _log[i].toLowerCase().contains('error')
                      ? MidnightHacker.negative
                      : MidnightHacker.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOutput() {
    final tabs = ['RAW', 'FINDINGS (${_findings.length})', 'ASSETS (${_assets.length})'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(tabs.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ChipButton(
                label: tabs[i],
                icon: Icons.receipt_long_outlined,
                active: _outputTab == i,
                compact: true,
                onTap: () => setState(() => _outputTab = i),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Container(
          height: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: MidnightHacker.primary)),
          child: _outputTab == 0
              ? (_outputRaw.isEmpty
                  ? Center(child: Text('No output yet.', style: MidnightHacker.labelDim))
                  : SingleChildScrollView(
                      child: SelectableText(_outputRaw, style: MidnightHacker.monoSmall),
                    ))
              : _buildJsonList(_outputTab == 1 ? _findings : _assets),
        ),
      ],
    );
  }

  Widget _buildJsonList(List<dynamic> items) {
    if (items.isEmpty) {
      return Center(child: Text('No records parsed.', style: MidnightHacker.labelDim));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final text = item is Map
            ? (item['title'] ?? item['key'] ?? item['name'] ?? jsonEncode(item)).toString()
            : item.toString();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text('- $text', style: MidnightHacker.monoSmall),
        );
      },
    );
  }
}

class OperationMetaView {
  final int index;
  final String name;
  final String binary;
  final String output;
  final int stage;
  final bool probe;

  const OperationMetaView({
    required this.index,
    required this.name,
    required this.binary,
    required this.output,
    required this.stage,
    required this.probe,
  });
}

class _Section extends StatelessWidget {
  final String index;
  final String title;
  final Widget child;

  const _Section({required this.index, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: MidnightHacker.primary)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(index, style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.positive)),
              const SizedBox(width: 10),
              Text(title, style: MidnightHacker.heading.copyWith(fontSize: 15, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(text, style: MidnightHacker.monoSmall.copyWith(color: color, fontSize: 10)),
    );
  }
}

class _ChipButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<_ChipButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? MidnightHacker.positive
        : (_hover ? MidnightHacker.primary : MidnightHacker.dimGreen);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 12,
            vertical: widget.compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: widget.active ? MidnightHacker.positive : MidnightHacker.dimGreen),
            color: widget.active ? MidnightHacker.positive.withOpacity(0.08) : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: widget.compact ? 12 : 14, color: color),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: MidnightHacker.monoSmall.copyWith(
                    color: color,
                    fontSize: widget.compact ? 10 : 11,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class GreenExecuteButton extends StatelessWidget {
  final bool running;
  final VoidCallback onTap;

  const GreenExecuteButton({super.key, required this.running, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: running ? null : onTap,
        icon: running
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: MidnightHacker.primary),
              )
            : const Icon(Icons.play_arrow_outlined, size: 18),
        label: Text(running ? 'RUNNING' : 'Execute',
            style: MidnightHacker.heading.copyWith(fontSize: 15, letterSpacing: 1)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: MidnightHacker.primary, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
    );
  }
}
