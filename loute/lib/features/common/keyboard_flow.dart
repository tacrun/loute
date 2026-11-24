import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/navigation_state.dart';

/// Keyboard-first operator flow (1-5-5.md §11.8).
/// g-prefix navigation (g c/j/f/w/v/p/t/a), / search, r run, d dry-run,
/// x cancel, Esc close, ? shortcut sheet.
class KeyboardFlow extends ConsumerStatefulWidget {
  final Widget child;
  const KeyboardFlow({super.key, required this.child});

  @override
  ConsumerState<KeyboardFlow> createState() => _KeyboardFlowState();
}

class _KeyboardFlowState extends ConsumerState<KeyboardFlow> {
  bool _gPending = false;
  bool _showShortcuts = false;

  void _handle(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final nav = ref.read(navigationProvider.notifier);

    if (_showShortcuts) {
      if (key == LogicalKeyboardKey.escape)
        setState(() => _showShortcuts = false);
      return;
    }

    if (_gPending) {
      _gPending = false;
      if (key == LogicalKeyboardKey.keyC)
        nav.setActiveScreen(ActiveScreen.capabilities);
      else if (key == LogicalKeyboardKey.keyJ)
        nav.setActiveScreen(ActiveScreen.jobs);
      else if (key == LogicalKeyboardKey.keyF)
        nav.setActiveScreen(ActiveScreen.findings);
      else if (key == LogicalKeyboardKey.keyW)
        nav.setActiveScreen(ActiveScreen.workspaces);
      else if (key == LogicalKeyboardKey.keyV)
        nav.setActiveScreen(ActiveScreen.vault);
      else if (key == LogicalKeyboardKey.keyP)
        nav.setActiveScreen(ActiveScreen.payloads);
      else if (key == LogicalKeyboardKey.keyT)
        nav.setActiveScreen(ActiveScreen.timeline);
      else if (key == LogicalKeyboardKey.keyA)
        nav.setActiveScreen(ActiveScreen.arena);
      else if (key == LogicalKeyboardKey.keyO)
        nav.setActiveScreen(ActiveScreen.ops);
      return;
    }

    if (key == LogicalKeyboardKey.keyG) {
      _gPending = true;
    } else if (key == LogicalKeyboardKey.question ||
        (key == LogicalKeyboardKey.slash && event.isShiftPressed)) {
      setState(() => _showShortcuts = true);
    } else if (key == LogicalKeyboardKey.escape) {
      nav.setActiveScreen(ActiveScreen.dashboard);
    }
    // r (run), d (dry-run), x (cancel) are delivered to the focused run panel
    // via FocusNode/Shortcuts in the run configuration widget.
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _handle(event);
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          widget.child,
          if (_showShortcuts) _shortcutSheet(),
        ],
      ),
    );
  }

  Widget _shortcutSheet() {
    final rows = [
      ['g c', 'Capabilities'],
      ['g j', 'Jobs'],
      ['g f', 'Findings'],
      ['g w', 'Workspaces'],
      ['g v', 'Vault'],
      ['g p', 'Payloads'],
      ['g t', 'Timeline'],
      ['g a', 'Arena'],
      ['g o', 'Operations'],
      ['/', 'Search'],
      ['r', 'Run'],
      ['d', 'Dry-run'],
      ['x', 'Cancel'],
      ['Esc', 'Close'],
      ['?', 'This sheet'],
    ];
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: SizedBox(
            width: 420,
            child: Card(
              color: Colors.black,
              shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.green),
                  borderRadius: BorderRadius.zero),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('KEYBOARD SHORTCUTS',
                        style: TextStyle(color: Colors.green, fontSize: 18)),
                    const SizedBox(height: 12),
                    ...rows.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            SizedBox(
                                width: 48,
                                child: Text(r[0],
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontFamily: 'monospace'))),
                            Expanded(child: Text(r[1])),
                          ]),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
