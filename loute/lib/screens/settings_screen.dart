import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import '../themes/midnight_hacker.dart';
import '../providers/navigation_state.dart';
import '../components/system_alert.dart';
import '../components/green_input.dart';
import '../components/green_button.dart';

/// Settings screen - configuration options for credentials, defaults, and saving.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Base controllers
  late TextEditingController _versionController;
  late TextEditingController _locationController;

  // Expanded tuning controllers
  late TextEditingController _concurrencyController;
  late TextEditingController _timeoutController;
  late TextEditingController _delayController;
  late TextEditingController _uaController;

  // Proxy settings
  late bool _enableProxy;
  late TextEditingController _proxyAddressController;

  // Integrations settings
  late TextEditingController _shodanController;
  late TextEditingController _vtController;
  late TextEditingController _censysIdController;
  late TextEditingController _censysSecretController;

  // Webhooks & Alerts settings
  late TextEditingController _webhookController;
  late bool _audioAlerts;
  late bool _debugLogs;
  late bool _disableSsl;

  @override
  void initState() {
    super.initState();
    final navState = ref.read(navigationProvider);

    _versionController = TextEditingController(text: navState.systemVersion);
    _locationController = TextEditingController(text: navState.outputSaveLocation);

    _concurrencyController = TextEditingController(text: navState.scanConcurrency.toString());
    _timeoutController = TextEditingController(text: navState.requestTimeoutSeconds.toString());
    _delayController = TextEditingController(text: navState.targetScanDelayMs.toString());
    _uaController = TextEditingController(text: navState.userAgent);

    _enableProxy = navState.enableProxy;
    _proxyAddressController = TextEditingController(text: navState.proxyAddress);

    _shodanController = TextEditingController(text: navState.shodanApiKey);
    _vtController = TextEditingController(text: navState.virusTotalApiKey);
    _censysIdController = TextEditingController(text: navState.censysApiId);
    _censysSecretController = TextEditingController(text: navState.censysApiSecret);

    _webhookController = TextEditingController(text: navState.webhookUrl);
    _audioAlerts = navState.audioAlerts;
    _debugLogs = navState.debugLogs;
    _disableSsl = navState.disableSslValidation;
  }

  @override
  void dispose() {
    _versionController.dispose();
    _locationController.dispose();
    _concurrencyController.dispose();
    _timeoutController.dispose();
    _delayController.dispose();
    _uaController.dispose();
    _proxyAddressController.dispose();
    _shodanController.dispose();
    _vtController.dispose();
    _censysIdController.dispose();
    _censysSecretController.dispose();
    _webhookController.dispose();
    super.dispose();
  }

  Future<void> _pickOutputDirectory() async {
    final selected = await getDirectoryPath();
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _locationController.text = selected;
      });
    }
  }

  void _save() {
    // ── Input Validation ──
    final requiredFields = {
      'System Version': _versionController.text,
      'Output Directory': _locationController.text,
      'Max Concurrency': _concurrencyController.text,
      'Timeout': _timeoutController.text,
      'Delay': _delayController.text,
      'HTTP User-Agent': _uaController.text,
    };

    if (_enableProxy) {
      requiredFields['Proxy Server Address'] = _proxyAddressController.text;
    }

    for (final entry in requiredFields.entries) {
      if (entry.value.trim().isEmpty) {
        SystemAlert.show(
          title: 'VALIDATION ERROR',
          message: '${entry.key.toUpperCase()} cannot be empty.',
          type: AlertType.negative,
          context: AlertContext.inputInvalid,
        );
        return;
      }
    }

    final notifier = ref.read(navigationProvider.notifier);

    // Save base config
    notifier.setSystemVersion(_versionController.text);
    notifier.setOutputSaveLocation(_locationController.text);

    // Save advanced configs
    final concurrency = int.tryParse(_concurrencyController.text) ?? 200;
    final timeout = int.tryParse(_timeoutController.text) ?? 10;
    final delay = int.tryParse(_delayController.text) ?? 100;

    notifier.setAdvancedSettings(
      concurrency: concurrency,
      timeout: timeout,
      delay: delay,
      ua: _uaController.text,
      proxy: _enableProxy,
      proxyAddr: _proxyAddressController.text,
      shodan: _shodanController.text,
      vt: _vtController.text,
      censysId: _censysIdController.text,
      censysSecret: _censysSecretController.text,
      webhook: _webhookController.text,
      sound: _audioAlerts,
      debug: _debugLogs,
      ignoreSsl: _disableSsl,
    );

    SystemAlert.show(
      title: 'CONFIGURATION PERSISTED',
      message: 'Settings updated successfully.',
      type: AlertType.positive,
      context: AlertContext.save,
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MidnightHacker.monoSmall.copyWith(
              color: MidnightHacker.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(color: MidnightHacker.dimGreen, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildCheckboxOption(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: value,
            activeColor: MidnightHacker.primary,
            checkColor: MidnightHacker.background,
            side: const BorderSide(color: MidnightHacker.primary),
            onChanged: (val) => onChanged(val ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveFields(List<Widget> fields, {double breakpoint = 720, double gap = 12}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i != fields.length - 1) SizedBox(height: gap),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < fields.length; i++) ...[
              Expanded(child: fields[i]),
              if (i != fields.length - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightHacker.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: MidnightHacker.primary, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.settings_outlined, color: MidnightHacker.primary, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'SYSTEM SETTINGS',
                      style: MidnightHacker.heading.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Category 1: Platform & Access ──
                _buildCategoryHeader('PLATFORM ACCESS & PATHS'),
                _responsiveFields([
                  GreenInput(
                    label: 'System Version',
                    hint: 'e.g. 0.0.1',
                    controller: _versionController,
                    obscureText: false,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GreenInput(
                          label: 'Output Directory',
                          hint: '/path/to/save/reports',
                          controller: _locationController,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: GreenButton(
                          label: 'BROWSE',
                          onPressed: _pickOutputDirectory,
                          borderColor: MidnightHacker.dimGreen,
                          textColor: MidnightHacker.primary,
                        ),
                      ),
                    ],
                  ),
                ], breakpoint: 760, gap: 16),

                // ── Category 2: Scanner Tuning ──
                _buildCategoryHeader('SCANNER RESOURCE TUNING'),
                _responsiveFields([
                  GreenInput(
                    label: 'Max Concurrency',
                    hint: '200',
                    controller: _concurrencyController,
                    keyboardType: TextInputType.number,
                  ),
                  GreenInput(
                    label: 'Timeout (Seconds)',
                    hint: '10',
                    controller: _timeoutController,
                    keyboardType: TextInputType.number,
                  ),
                  GreenInput(
                    label: 'Delay (Milliseconds)',
                    hint: '100',
                    controller: _delayController,
                    keyboardType: TextInputType.number,
                  ),
                ], breakpoint: 760),
                const SizedBox(height: 12),
                GreenInput(
                  label: 'HTTP User-Agent',
                  hint: 'Custom User-Agent header string',
                  controller: _uaController,
                ),

                // ── Category 3: Routing & Proxying ──
                _buildCategoryHeader('TRAFFIC ROUTING & PROXIES'),
                _buildCheckboxOption(
                  'ENABLE NETWORK PROXY (FORWARD SYSTEM SCANS)',
                  _enableProxy,
                  (val) => setState(() => _enableProxy = val),
                ),
                if (_enableProxy) ...[
                  const SizedBox(height: 8),
                  GreenInput(
                    label: 'Proxy Server Address',
                    hint: 'http://127.0.0.1:8080',
                    controller: _proxyAddressController,
                  ),
                ],

                // ── Category 4: Integrations ──
                _buildCategoryHeader('THREAT INTEL & API KEYS'),
                _responsiveFields([
                  GreenInput(
                    label: 'Shodan API Key',
                    hint: 'Enter Shodan token',
                    controller: _shodanController,
                    obscureText: true,
                  ),
                  GreenInput(
                    label: 'VirusTotal API Key',
                    hint: 'Enter VirusTotal token',
                    controller: _vtController,
                    obscureText: true,
                  ),
                ], breakpoint: 760, gap: 16),
                const SizedBox(height: 12),
                _responsiveFields([
                  GreenInput(
                    label: 'Censys API ID',
                    hint: 'Censys client id',
                    controller: _censysIdController,
                    obscureText: true,
                  ),
                  GreenInput(
                    label: 'Censys API Secret',
                    hint: 'Censys client secret',
                    controller: _censysSecretController,
                    obscureText: true,
                  ),
                ], breakpoint: 760, gap: 16),

                // ── Category 5: Alerts & Verbosity ──
                _buildCategoryHeader('REPORTING, ALERTS & VERBOSITY'),
                GreenInput(
                  label: 'Notification Webhook URL',
                  hint: 'https://discord.com/api/webhooks/...',
                  controller: _webhookController,
                ),
                const SizedBox(height: 12),
                _responsiveFields([
                  Column(
                    children: [
                      _buildCheckboxOption(
                        'PLAY AUDIO ALERTS ON CRITICAL DISCOVERIES',
                        _audioAlerts,
                        (val) => setState(() => _audioAlerts = val),
                      ),
                      _buildCheckboxOption(
                        'WRITE EXTENSIVE DEBUG LOGS TO DISK',
                        _debugLogs,
                        (val) => setState(() => _debugLogs = val),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      _buildCheckboxOption(
                        'IGNORE TARGET SSL VALIDATION ERRORS',
                        _disableSsl,
                        (val) => setState(() => _disableSsl = val),
                      ),
                    ],
                  ),
                ], breakpoint: 760, gap: 16),

                const SizedBox(height: 32),

                // Save Button
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MidnightHacker.primary,
                        foregroundColor: MidnightHacker.background,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      icon: const Icon(Icons.save_outlined, color: MidnightHacker.background, size: 20),
                      label: Text(
                        'SAVE SETTINGS',
                        style: MidnightHacker.monoStyle.copyWith(
                          color: MidnightHacker.background,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _save,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _RadioOption({
    required this.label,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: MidnightHacker.background,
          border: Border.all(
            color: active ? MidnightHacker.primary : MidnightHacker.dimGreen,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? MidnightHacker.positive : MidnightHacker.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: MidnightHacker.monoSmall.copyWith(
                color: active ? MidnightHacker.primary : MidnightHacker.dimGreen,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
