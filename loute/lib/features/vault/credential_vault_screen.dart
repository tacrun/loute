import 'package:flutter/material.dart';
import '../common/screen_shell.dart';

/// Credential Vault - secret index, hash table, validation state (§11.1, route /vault).
class CredentialVaultScreen extends StatelessWidget {
  const CredentialVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final creds = [
      ['admin@target', 'NTLM', 'validated'],
      ['svc_backup', 'hash', 'pending'],
      ['root@10.0.0.5', 'SSH key', 'validated'],
    ];
    return ScreenShell(
      title: 'CREDENTIAL VAULT',
      subtitle: 'SECRET INDEX · HASH TABLE · VALIDATION STATE',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: const [
              Chip(label: Text('CREDENTIALS: 3')),
              Chip(label: Text('VALIDATED: 2')),
              Chip(label: Text('HASHES: 1')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: creds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                return ListTile(
                  leading: const Icon(Icons.key_outlined, color: Colors.green),
                  title: Text(creds[i][0]),
                  subtitle: Text('${creds[i][1]} · value redacted (***)'),
                  trailing: Chip(label: Text(creds[i][2])),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
