import 'package:flutter/material.dart';
import '../common/screen_shell.dart';

/// CTF / Lab Arena — challenges, flags, score, hint ladder (§11.1, /arena).
/// CTF is a first-class phase; all other phases stay available while active.
class ArenaScreen extends StatelessWidget {
  const ArenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final challenges = [
      ['WEB', 'web-app-security', '100', 'easy'],
      ['PWN', 'binary-exploitation', '300', 'hard'],
      ['REV', 'reverse-engineering', '200', 'medium'],
      ['CRYPTO', 'cryptography', '150', 'medium'],
    ];
    return ScreenShell(
      title: 'CTF / LAB ARENA',
      subtitle: 'CHALLENGES · FLAGS · SCORE',
      body: Column(
        children: [
          Row(
            children: const [
              Chip(label: Text('SCORE: 450')),
              SizedBox(width: 8),
              Chip(label: Text('FLAGS: 3/15')),
              SizedBox(width: 8),
              Chip(label: Text('RANK: 12')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 3.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: challenges
                  .map((c) => Card(
                        shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Colors.green),
                            borderRadius: BorderRadius.zero),
                        child: ListTile(
                          leading: const Icon(Icons.flag_outlined,
                              color: Colors.green),
                          title: Text('${c[0]} · ${c[2]} pts'),
                          subtitle: Text('${c[1]} · ${c[3]}'),
                          onTap: () {},
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
