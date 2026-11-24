import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/phase_model.dart';
import '../models/phase_registry.dart';
import '../models/report_model.dart';

/// Active screens available in LOUTE.
enum ActiveScreen {
  dashboard,
  documentation,
  settings,
  reports,
  action,
}

/// The global navigation state.
class NavigationState {
  final ActiveScreen activeScreen;
  final String? selectedPhaseId;
  final String? selectedModuleId;
  final String? selectedActionId;
  final bool sidePanelCollapsed;
  final String navBarPreference; // 'side' or 'bottom'
  final String systemVersion;
  final String outputSaveLocation;
  final List<ReportRecord> reports;
  final ReportRecord? selectedReport;

  // Tree navigation state
  final Set<String> expandedPhases;
  final Set<String> expandedModules;

  // Expanded system configurations
  final int scanConcurrency;
  final int requestTimeoutSeconds;
  final int targetScanDelayMs;
  final String userAgent;
  final bool enableProxy;
  final String proxyAddress;
  final String shodanApiKey;
  final String virusTotalApiKey;
  final String censysApiId;
  final String censysApiSecret;
  final String webhookUrl;
  final bool audioAlerts;
  final bool debugLogs;
  final bool disableSslValidation;

  const NavigationState({
    this.activeScreen = ActiveScreen.dashboard,
    this.selectedPhaseId,
    this.selectedModuleId,
    this.selectedActionId,
    this.sidePanelCollapsed = false,
    this.navBarPreference = 'side',
    this.systemVersion = '1.5.5',
    this.outputSaveLocation = '/home/iturn/loute/outputs/reports',
    this.reports = const [],
    this.selectedReport,
    this.expandedPhases = const {},
    this.expandedModules = const {},
    this.scanConcurrency = 200,
    this.requestTimeoutSeconds = 10,
    this.targetScanDelayMs = 100,
    this.userAgent = 'LOUTE-Agent/1.0',
    this.enableProxy = false,
    this.proxyAddress = 'http://127.0.0.1:8080',
    this.shodanApiKey = '',
    this.virusTotalApiKey = '',
    this.censysApiId = '',
    this.censysApiSecret = '',
    this.webhookUrl = '',
    this.audioAlerts = false,
    this.debugLogs = false,
    this.disableSslValidation = true,
  });

  NavigationState copyWith({
    ActiveScreen? activeScreen,
    String? selectedPhaseId,
    String? selectedModuleId,
    String? selectedActionId,
    bool? sidePanelCollapsed,
    String? navBarPreference,
    String? systemVersion,
    String? outputSaveLocation,
    List<ReportRecord>? reports,
    ReportRecord? selectedReport,
    bool clearSelectedReport = false,
    Set<String>? expandedPhases,
    Set<String>? expandedModules,
    int? scanConcurrency,
    int? requestTimeoutSeconds,
    int? targetScanDelayMs,
    String? userAgent,
    bool? enableProxy,
    String? proxyAddress,
    String? shodanApiKey,
    String? virusTotalApiKey,
    String? censysApiId,
    String? censysApiSecret,
    String? webhookUrl,
    bool? audioAlerts,
    bool? debugLogs,
    bool? disableSslValidation,
  }) {
    return NavigationState(
      activeScreen: activeScreen ?? this.activeScreen,
      selectedPhaseId: selectedPhaseId ?? this.selectedPhaseId,
      selectedModuleId: selectedModuleId ?? this.selectedModuleId,
      selectedActionId: selectedActionId ?? this.selectedActionId,
      sidePanelCollapsed: sidePanelCollapsed ?? this.sidePanelCollapsed,
      navBarPreference: navBarPreference ?? this.navBarPreference,
      systemVersion: systemVersion ?? this.systemVersion,
      outputSaveLocation: outputSaveLocation ?? this.outputSaveLocation,
      reports: reports ?? this.reports,
      selectedReport: clearSelectedReport ? null : (selectedReport ?? this.selectedReport),
      expandedPhases: expandedPhases ?? this.expandedPhases,
      expandedModules: expandedModules ?? this.expandedModules,
      scanConcurrency: scanConcurrency ?? this.scanConcurrency,
      requestTimeoutSeconds: requestTimeoutSeconds ?? this.requestTimeoutSeconds,
      targetScanDelayMs: targetScanDelayMs ?? this.targetScanDelayMs,
      userAgent: userAgent ?? this.userAgent,
      enableProxy: enableProxy ?? this.enableProxy,
      proxyAddress: proxyAddress ?? this.proxyAddress,
      shodanApiKey: shodanApiKey ?? this.shodanApiKey,
      virusTotalApiKey: virusTotalApiKey ?? this.virusTotalApiKey,
      censysApiId: censysApiId ?? this.censysApiId,
      censysApiSecret: censysApiSecret ?? this.censysApiSecret,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      audioAlerts: audioAlerts ?? this.audioAlerts,
      debugLogs: debugLogs ?? this.debugLogs,
      disableSslValidation: disableSslValidation ?? this.disableSslValidation,
    );
  }

  ActionItem? get currentAction {
    if (selectedActionId == null) return null;
    for (final phase in PhaseRegistry.phases) {
      for (final module in phase.modules) {
        for (final action in module.actions) {
          if (action.id == selectedActionId) return action;
        }
      }
    }
    return null;
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(const NavigationState());

  void selectAction(String phaseId, String moduleId, String actionId) {
    state = state.copyWith(
      activeScreen: ActiveScreen.action,
      selectedPhaseId: phaseId,
      selectedModuleId: moduleId,
      selectedActionId: actionId,
    );
  }

  void setActiveScreen(ActiveScreen screen) {
    state = state.copyWith(
      activeScreen: screen,
      selectedPhaseId: screen == ActiveScreen.action ? state.selectedPhaseId : null,
      selectedModuleId: screen == ActiveScreen.action ? state.selectedModuleId : null,
      selectedActionId: screen == ActiveScreen.action ? state.selectedActionId : null,
    );
  }

  void toggleSidePanelCollapsed() {
    state = state.copyWith(sidePanelCollapsed: !state.sidePanelCollapsed);
  }

  void togglePhaseExpanded(String phaseId) {
    final updated = Set<String>.from(state.expandedPhases);
    if (updated.contains(phaseId)) {
      updated.remove(phaseId);
    } else {
      updated.add(phaseId);
    }
    state = state.copyWith(expandedPhases: updated);
  }

  void toggleModuleExpanded(String moduleId) {
    final updated = Set<String>.from(state.expandedModules);
    if (updated.contains(moduleId)) {
      updated.remove(moduleId);
    } else {
      updated.add(moduleId);
    }
    state = state.copyWith(expandedModules: updated);
  }

  void setNavBarPreference(String pref) {
    state = state.copyWith(navBarPreference: pref);
  }

  void setSystemVersion(String version) {
    state = state.copyWith(systemVersion: version);
  }

  void setOutputSaveLocation(String loc) {
    state = state.copyWith(outputSaveLocation: loc);
  }

  void setAdvancedSettings({
    required int concurrency,
    required int timeout,
    required int delay,
    required String ua,
    required bool proxy,
    required String proxyAddr,
    required String shodan,
    required String vt,
    required String censysId,
    required String censysSecret,
    required String webhook,
    required bool sound,
    required bool debug,
    required bool ignoreSsl,
  }) {
    state = state.copyWith(
      scanConcurrency: concurrency,
      requestTimeoutSeconds: timeout,
      targetScanDelayMs: delay,
      userAgent: ua,
      enableProxy: proxy,
      proxyAddress: proxyAddr,
      shodanApiKey: shodan,
      virusTotalApiKey: vt,
      censysApiId: censysId,
      censysApiSecret: censysSecret,
      webhookUrl: webhook,
      audioAlerts: sound,
      debugLogs: debug,
      disableSslValidation: ignoreSsl,
    );
  }

  void addReport(ReportRecord report) {
    state = state.copyWith(reports: [...state.reports, report]);
  }

  void setReports(List<ReportRecord> reports) {
    state = state.copyWith(reports: reports);
  }

  void deleteReport(String reportId) {
    final updated = state.reports.where((r) => r.id != reportId).toList();
    final clearSelected = state.selectedReport?.id == reportId;
    state = state.copyWith(
      reports: updated,
      clearSelectedReport: clearSelected,
    );
  }

  void selectReport(ReportRecord report) {
    state = state.copyWith(selectedReport: report);
  }

  void clearReportSelection() {
    state = state.copyWith(clearSelectedReport: true);
  }
}

final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>(
  (ref) => NavigationNotifier(),
);
