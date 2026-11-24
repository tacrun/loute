import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/navigation_state.dart';

/// Keyboard-first operator flow.
/// g-prefix navigation, ? opens the shortcut sheet, Esc returns to dashboard.
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
      if (key == LogicalKeyboardKey.escape) {
        setState(() => _showShortcuts = false);
      }
      return;
    }

    if (_gPending) {
      _gPending = false;
      if (key == LogicalKeyboardKey.keyD) {
        nav.setActiveScreen(ActiveScreen.dashboard);
      } else if (key == LogicalKeyboardKey.keyT) {
        nav.setActiveScreen(ActiveScreen.toolManager);
      } else if (key == LogicalKeyboardKey.keyR) {
        nav.setActiveScreen(ActiveScreen.reports);
      } else if (key == LogicalKeyboardKey.keyS) {
        nav.setActiveScreen(ActiveScreen.settings);
      } else if (key == LogicalKeyboardKey.keyC) {
        nav.setActiveScreen(ActiveScreen.documentation);
      }
      return;
    }

    if (key == LogicalKeyboardKey.keyG) {
      _gPending = true;
    } else if (key == LogicalKeyboardKey.question ||
        (key == LogicalKeyboardKey.slash &&
            HardwareKeyboard.instance.isShiftPressed)) {
      setState(() => _showShortcuts = true);
    } else if (key == LogicalKeyboardKey.escape) {
      nav.setActiveScreen(ActiveScreen.dashboard);
    }
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
      ['g d', 'Dashboard'],
      ['g t', 'Tool Manager'],
      ['g r', 'Reports'],
      ['g s', 'Settings'],
      ['g c', 'Documentation'],
      ['Esc', 'Dashboard'],
      ['?', 'This sheet'],
    ];
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: SizedBox(
            width: 360,
            child: Card(
              color: Colors.black,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.green),
                borderRadius: BorderRadius.zero,
              ),
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
                                      fontFamily: 'monospace')),
                            ),
                            Expanded(
                              child: Text(r[1],
                                  style: const TextStyle(color: Colors.green)),
                            ),
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
