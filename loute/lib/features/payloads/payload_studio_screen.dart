import 'package:flutter/material.dart';
import '../common/screen_shell.dart';

/// Payload Studio - builder canvas, artifact preview, delivery binding (§11.1, /payloads).
class PayloadStudioScreen extends StatelessWidget {
  const PayloadStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final builders = [
      ['SCRIPT PAYLOAD', 'PowerShell / Bash / Python / JS'],
      ['WEB SHELL', 'PHP / ASPX / JSP'],
      ['C2 PROFILE PAYLOAD', 'Profile-bound beacon'],
      ['MSFVENOM WRAP', 'Multi-format matrix'],
    ];
    return ScreenShell(
      title: 'PAYLOAD STUDIO',
      subtitle: 'BUILD · STAGE · DELIVER',
      actions: [
        IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New payload',
            onPressed: () {})
      ],
      body: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: builders
            .map((b) => Card(
                  shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.green),
                      borderRadius: BorderRadius.zero),
                  child: ListTile(
                    leading: const Icon(Icons.construction_outlined,
                        color: Colors.green),
                    title: Text(b[0]),
                    subtitle: Text(b[1]),
                    onTap: () {},
                  ),
                ))
            .toList(),
      ),
    );
  }
}
