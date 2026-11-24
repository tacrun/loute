import 'package:flutter/material.dart';
import '../common/screen_shell.dart';

/// Campaign Timeline - chronological operator + system events (§11.1, /timeline).
class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = [
      [
        '09:12:01',
        'SYSTEM',
        'Runtime initialized - 241 capabilities, hash verified'
      ],
      ['09:12:04', 'JOB', 'recon.subdomain-discovery queued (interactive)'],
      ['09:12:09', 'FINDING', '12 subdomain assets normalized'],
      ['09:13:22', 'JOB', 'surface.port-discovery completed'],
    ];
    return ScreenShell(
      title: 'CAMPAIGN TIMELINE',
      subtitle: 'OPERATOR + SYSTEM EVENTS',
      body: ListView.separated(
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, i) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 70,
                  child: Text(events[i][0],
                      style: const TextStyle(
                          fontFamily: 'monospace', color: Colors.green))),
              SizedBox(width: 70, child: Chip(label: Text(events[i][1]))),
              Expanded(child: Text(events[i][2])),
            ],
          );
        },
      ),
    );
  }
}
