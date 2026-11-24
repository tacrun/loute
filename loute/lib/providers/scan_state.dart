import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ScanStatus { idle, running, complete, error }

class ScanState {
  final ScanStatus status;
  final double progress; // 0.0 - 1.0
  final String? htmlOutput;
  final List<String> logs;
  final String? errorMessage;

  const ScanState({
    this.status = ScanStatus.idle,
    this.progress = 0.0,
    this.htmlOutput,
    this.logs = const [],
    this.errorMessage,
  });

  ScanState copyWith({
    ScanStatus? status,
    double? progress,
    String? htmlOutput,
    List<String>? logs,
    String? errorMessage,
  }) {
    return ScanState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      htmlOutput: htmlOutput ?? this.htmlOutput,
      logs: logs ?? this.logs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier() : super(const ScanState());

  void startScan() {
    state = state.copyWith(
      status: ScanStatus.running,
      progress: 0.0,
      logs: [],
      htmlOutput: null,
      errorMessage: null,
    );
  }

  void updateProgress(double p) {
    state = state.copyWith(progress: p);
  }

  void addLog(String line) {
    state = state.copyWith(logs: [...state.logs, line]);
  }

  void completeScan(String html) {
    state = state.copyWith(
      status: ScanStatus.complete,
      progress: 1.0,
      htmlOutput: html,
    );
  }

  void failScan(String error) {
    state = state.copyWith(
      status: ScanStatus.error,
      errorMessage: error,
    );
  }

  void reset() {
    state = const ScanState();
  }
}

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(),
);
