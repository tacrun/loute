import 'package:flutter/material.dart';
import '../common/screen_shell.dart';

/// Target Workspaces - create/switch/import/export workspaces (§11.1, route /ws).
class WorkspacesScreen extends StatelessWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workspaces = [
      ['engagement-default', 'engagement', '241 caps · active'],
      ['lab-local', 'lab', 'sandbox · idle'],
      ['ctf-arena-01', 'ctf', 'challenges · idle'],
    ];
    return ScreenShell(
      title: 'TARGET WORKSPACES',
      subtitle: 'CREATE · SWITCH · IMPORT · EXPORT',
      actions: [
        IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New workspace (n)',
            onPressed: () {}),
        IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import',
            onPressed: () {}),
      ],
      body: ListView.separated(
        itemCount: workspaces.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final name = workspaces[i][0];
          final kind = workspaces[i][1];
          final meta = workspaces[i][2];
          return ListTile(
            leading: Icon(
                kind == 'ctf' ? Icons.emoji_events : Icons.folder_outlined,
                color: Colors.green),
            title: Text(name),
            subtitle: Text('$kind · $meta'),
            trailing: IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: 'Export',
                onPressed: () {}),
            onTap: () {},
          );
        },
      ),
    );
  }
}
