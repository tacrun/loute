import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'themes/midnight_hacker.dart';
import 'screens/main_scan_screen.dart';
import 'src/rust/frb_generated.dart';
import 'services/connectivity_service.dart';
import 'features/common/keyboard_flow.dart';

import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await RustLib.init();
  ConnectivityService().startMonitoring();
  runApp(const ProviderScope(child: LouteApp()));
}

class LouteApp extends StatelessWidget {
  const LouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LOUTE — Autonomous Bug Bounty Framework',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: MidnightHacker.themeData,
      home: const KeyboardFlow(child: MainScanScreen()),
    );
  }
}
