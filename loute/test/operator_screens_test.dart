// Widget tests for V1.5.5 operator screens (1-5-5.md §18.4).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loute/features/ws/workspaces_screen.dart';
import 'package:loute/features/vault/credential_vault_screen.dart';
import 'package:loute/features/payloads/payload_studio_screen.dart';
import 'package:loute/features/timeline/timeline_screen.dart';
import 'package:loute/features/arena/arena_screen.dart';
import 'package:loute/features/common/screen_shell.dart';

void main() {
  testWidgets('all operator screens render without error', (tester) async {
    final screens = <Widget>[
      const ProviderScope(child: WorkspacesScreen()),
      const ProviderScope(child: CredentialVaultScreen()),
      const ProviderScope(child: PayloadStudioScreen()),
      const ProviderScope(child: TimelineScreen()),
      const ProviderScope(child: ArenaScreen()),
    ];
    for (final screen in screens) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ScreenShell displays title and version', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ScreenShell(title: 'TEST SCREEN', body: SizedBox()),
    ));
    expect(find.text('TEST SCREEN'), findsOneWidget);
    expect(find.textContaining('V1.5.5'), findsOneWidget);
  });
}
