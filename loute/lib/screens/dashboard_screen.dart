import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/midnight_hacker.dart';
import '../providers/navigation_state.dart';
import '../models/phase_registry.dart';
import '../components/system_alert.dart';

/// Dashboard Screen - displays logo, name, stats, 6 shortcut cards, and system analytics.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    final reports = navState.reports;
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 900;
    final isCompact = width < 600;

    int countSeverity(String sev) {
      int c = 0;
      for (final r in reports) {
        for (final f in r.findings) {
          if ((f['severity']?.toString().toLowerCase() ?? '') == sev) c++;
        }
      }
      return c;
    }

    final critical = countSeverity('critical');
    final high = countSeverity('high');
    final medium = countSeverity('medium');
    final low = countSeverity('low');
    final info = countSeverity('info');
    final completed = reports.where((r) => r.status.toUpperCase() == 'SUCCESS' || r.status.toUpperCase() == 'COMPLETED').length;

    return Scaffold(
      backgroundColor: MidnightHacker.background,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 16 : 24, horizontal: isCompact ? 12 : 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              const SizedBox(height: 16),
              // Perfect centered brand logo in exact usability dimension (80x80)
              Image.asset(
                'assets/icons/logo.png',
                height: 80,
                width: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'LOUTE',
                style: MidnightHacker.headingLarge.copyWith(
                  fontSize: isSmall ? 32 : 48,
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Autonomous Bug Bounty Framework',
                style: MidnightHacker.label.copyWith(
                  fontSize: isSmall ? 14 : 18,
                  color: MidnightHacker.dimGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Native Rust Engine • Flutter UI • Zero External Dependencies',
                style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Symmetrical Stats Display
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatBox(value: '10', label: 'PHASES', icon: Icons.lan_outlined),
                  _StatBox(value: '22', label: 'MODULES', icon: Icons.view_module_outlined),
                  _StatBox(value: '107', label: 'ACTIONS', icon: Icons.bolt_outlined),
                  _StatBox(value: '${reports.length}', label: 'REPORTS', icon: Icons.assessment_outlined),
                  _StatBox(value: '${critical + high + medium + low + info}', label: 'FINDINGS', icon: Icons.bug_report_outlined),
                ],
              ),
              const SizedBox(height: 32),

              // 12 Navigation / Action / Severity Cards
              SizedBox(
                width: double.infinity,
                child: GridView.count(
                  crossAxisCount: width > 1200 ? 6 : width > 900 ? 4 : width > 600 ? 3 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isSmall ? 1.35 : 1.25,
                  children: [
                    _DashboardCard(
                      title: 'DNS Brute-force',
                      description: 'Enumerate subdomains with native resolver.',
                      icon: Icons.dns_outlined,
                      onTap: () => _selectActionById(context, ref, 'dns_bruteforce'),
                    ),
                    _DashboardCard(
                      title: 'Cloud Provider',
                      description: 'Detect hosting and CDN architecture.',
                      icon: Icons.cloud_queue_outlined,
                      onTap: () => _selectActionById(context, ref, 'cloud_provider'),
                    ),
                    _DashboardCard(
                      title: 'Wildcard Check',
                      description: 'Identify wildcard DNS behavior.',
                      icon: Icons.radar_outlined,
                      onTap: () => _selectActionById(context, ref, 'wildcard_detect'),
                    ),
                    _DashboardCard(
                      title: 'Critical',
                      description: '$critical findings across saved reports.',
                      icon: Icons.warning_amber_outlined,
                      highlightColor: const Color(0xFFFF3B30),
                      badge: '$critical',
                      onTap: () => ref.read(navigationProvider.notifier).setActiveScreen(ActiveScreen.reports),
                    ),
                    _DashboardCard(
                      title: 'High',
                      description: '$high findings requiring review.',
                      icon: Icons.error_outline,
                      highlightColor: const Color(0xFFFF9500),
                      badge: '$high',
                      onTap: () => ref.read(navigationProvider.notifier).setActiveScreen(ActiveScreen.reports),
                    ),
                    _DashboardCard(
                      title: 'Medium',
                      description: '$medium findings to triage.',
                      icon: Icons.report_problem_outlined,
                      highlightColor: const Color(0xFFFFCC00),
                      badge: '$medium',
                      onTap: () => ref.read(navigationProvider.notifier).setActiveScreen(ActiveScreen.reports),
                    ),
                    _DashboardCard(
                      title: 'Low',
                      description: '$low low-severity observations.',
                      icon: Icons.info_outline,
                      highlightColor: MidnightHacker.primary,
                      badge: '$low',
                      onTap: () => ref.read(navigationProvider.notifier).setActiveScreen(ActiveScreen.reports),
                    ),
                    _DashboardCard(
                      title: 'Informational',
                      description: '$info informational findings.',
                      icon: Icons.lightbulb_outline,
                      highlightColor: const Color(0xFF5AC8FA),
                      badge: '$info',
                      onTap: () => ref.read(navigationProvider.notifier).setActiveScreen(ActiveScreen.reports),
                    ),
                    _DashboardCard(
                      title: 'Completed',
                      description: '$completed successful scan reports.',
                      icon: Icons.check_circle_outline,
                      highlightColor: MidnightHacker.positive,
                      badge: '$completed',
                      onTap: () => ref.read(navigationProvider.notifier).setActiveScreen(ActiveScreen.reports),
                    ),
                    _DashboardCard(
                      title: 'Documentation',
                      description: 'Operational manual and phase guides.',
                      icon: Icons.menu_book_outlined,
                      onTap: () => ref.read(navigationProvider.notifier).setActiveScreen(ActiveScreen.documentation),
                    ),
                    _DashboardCard(
                      title: 'Settings',
                      description: 'Runtime, proxy, and API configuration.',
                      icon: Icons.tune_outlined,
                      onTap: () => ref.read(navigationProvider.notifier).setActiveScreen(ActiveScreen.settings),
                    ),
                    _DashboardCard(
                      title: 'Reports',
                      description: 'Browse, export, and review outputs.',
                      icon: Icons.assessment_outlined,
                      onTap: () => ref.read(navigationProvider.notifier).setActiveScreen(ActiveScreen.reports),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── System Analytics Visualizations Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: MidnightHacker.primary, width: 1),
                  color: MidnightHacker.background,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, color: MidnightHacker.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'SYSTEM ANALYTICS & THREAT MAP',
                            style: MidnightHacker.monoStyle.copyWith(
                              color: MidnightHacker.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: MidnightHacker.dimGreen, height: 24),
                    const SizedBox(height: 8),

                    // Cyber-Attack World Map Simulation
                    const _CyberAttackSimulationCard(),
                    const SizedBox(height: 24),

                    // Layout responsive column or row for graphs
                    if (isSmall) ...[
                      const _NetworkTopologyCard(),
                      const SizedBox(height: 20),
                      const _LineChartCard(),
                      const SizedBox(height: 20),
                      const _BarChartCard(),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(child: _NetworkTopologyCard()),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                const _LineChartCard(),
                                const SizedBox(height: 16),
                                const _BarChartCard(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }

  void _selectActionById(BuildContext context, WidgetRef ref, String rustFunc) {
    for (final phase in PhaseRegistry.phases) {
      for (final module in phase.modules) {
        for (final action in module.actions) {
          if (action.rustFunction == rustFunc) {
            ref.read(navigationProvider.notifier).selectAction(
                  phase.id,
                  module.id,
                  action.id,
                );
            return;
          }
        }
      }
    }
    // If not found, show snackbar
    _showMockSnackbar(context, rustFunc);
  }

  void _showMockSnackbar(BuildContext context, String title) {
    SystemAlert.show(
      title: 'MODULE ACTIVATED',
      message: '$title module activated.',
      type: AlertType.ignorable,
      context: AlertContext.run,
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatBox({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: MidnightHacker.panelBg.withOpacity(0.4),
        border: Border.all(color: MidnightHacker.primary.withOpacity(0.45), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: MidnightHacker.primary, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: MidnightHacker.heading.copyWith(fontSize: 20, color: MidnightHacker.positive),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: MidnightHacker.monoSmall.copyWith(fontSize: 9, color: MidnightHacker.dimGreen, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color? highlightColor;
  final String? badge;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.description,
    required this.icon,
    this.highlightColor,
    this.badge,
    required this.onTap,
  });

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.highlightColor ?? MidnightHacker.primary;
    final borderColor = _hovering ? color : color.withOpacity(0.45);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovering ? color.withOpacity(0.06) : MidnightHacker.background,
            border: Border.all(color: borderColor, width: _hovering ? 1.5 : 1),
            boxShadow: _hovering
                ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 16, spreadRadius: 1)]
                : const [],
          ),
          child: Stack(
            children: [
              if (widget.badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: color.withOpacity(0.6)),
                      color: color.withOpacity(0.08),
                    ),
                    child: Text(
                      widget.badge!,
                      style: MidnightHacker.monoSmall.copyWith(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: _hovering ? MidnightHacker.positive : color,
                    size: 22,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title.toUpperCase(),
                    style: MidnightHacker.monoSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    style: MidnightHacker.monoSmall.copyWith(
                      color: MidnightHacker.dimGreen,
                      fontSize: 9,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Network Services Topology Card ──
class _NetworkTopologyCard extends StatefulWidget {
  const _NetworkTopologyCard();

  @override
  State<_NetworkTopologyCard> createState() => _NetworkTopologyCardState();
}

class _NetworkTopologyCardState extends State<_NetworkTopologyCard> {
  double _pulseOffset = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _pulseOffset = (_pulseOffset + 0.02) % 1.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: MidnightHacker.dimGreen),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE HOST INFRASTRUCTURE TOPOLOGY',
            style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 9),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRect(
              child: CustomPaint(
                size: Size.infinite,
                painter: _TopologyPainter(_pulseOffset),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopologyPainter extends CustomPainter {
  final double pulseOffset;
  _TopologyPainter(this.pulseOffset);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintLine = Paint()
      ..color = MidnightHacker.dimGreen.withOpacity(0.3)
      ..strokeWidth = 1;

    final paintPulse = Paint()
      ..color = MidnightHacker.positive
      ..style = PaintingStyle.fill;

    // Node locations
    final nodes = [
      {'name': 'Database', 'angle': 0.0, 'dist': 80.0},
      {'name': 'API Gateway', 'angle': 72.0, 'dist': 80.0},
      {'name': 'Local Proxy', 'angle': 144.0, 'dist': 80.0},
      {'name': 'DNS Nameserver', 'angle': 216.0, 'dist': 80.0},
      {'name': 'CDN Edge', 'angle': 288.0, 'dist': 80.0},
    ];

    // Draw connection lines & pulsing signals
    for (final node in nodes) {
      final rad = (node['angle'] as double) * pi / 180.0;
      final dist = node['dist'] as double;
      final target = Offset(
        center.dx + cos(rad) * dist,
        center.dy + sin(rad) * dist,
      );

      // Line
      canvas.drawLine(center, target, paintLine);

      // Pulse
      final pulsePos = Offset(
        center.dx + cos(rad) * dist * pulseOffset,
        center.dy + sin(rad) * dist * pulseOffset,
      );
      canvas.drawCircle(pulsePos, 3, paintPulse);

      // Draw leaf node outline
      final nodePaint = Paint()
        ..color = MidnightHacker.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(target, 8, nodePaint);

      // Text label
      final textPainter = TextPainter(
        text: TextSpan(
          text: node['name'] as String,
          style: const TextStyle(
            color: MidnightHacker.primary,
            fontFamily: 'monospace',
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      // Offset label so it does not overlap circle
      final labelOffset = Offset(
        target.dx + (cos(rad) >= 0 ? 12.0 : -textPainter.width - 12.0),
        target.dy - 4.0,
      );
      textPainter.paint(canvas, labelOffset);
    }

    // Draw Central Host Node
    final centralPaint = Paint()
      ..color = MidnightHacker.positive
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12, centralPaint);

    final centralOutline = Paint()
      ..color = MidnightHacker.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 16, centralOutline);

    final hostLabel = TextPainter(
      text: const TextSpan(
        text: 'LOUTE HOST',
        style: TextStyle(
          color: MidnightHacker.background,
          fontFamily: 'monospace',
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hostLabel.paint(canvas, center - Offset(hostLabel.width / 2, hostLabel.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter oldDelegate) {
    return oldDelegate.pulseOffset != pulseOffset;
  }
}

// ── Line Chart Card ──
class _LineChartCard extends StatelessWidget {
  const _LineChartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 115,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: MidnightHacker.dimGreen),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCAN ACTIVITY GRAPH (REQUESTS / SEC)',
            style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 9),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = MidnightHacker.dimGreen.withOpacity(0.15)
      ..strokeWidth = 0.5;

    // Draw Grid
    const gridCols = 6;
    const gridRows = 3;
    for (int i = 1; i < gridCols; i++) {
      final dx = (size.width / gridCols) * i;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (int i = 1; i < gridRows; i++) {
      final dy = (size.height / gridRows) * i;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    // Coordinates path data
    final points = [
      Offset(0.0, size.height * 0.8),
      Offset(size.width * 0.15, size.height * 0.65),
      Offset(size.width * 0.3, size.height * 0.72),
      Offset(size.width * 0.45, size.height * 0.4),
      Offset(size.width * 0.6, size.height * 0.55),
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.9, size.height * 0.3),
      Offset(size.width, size.height * 0.1),
    ];

    // Draw glowing bezier line
    final linePaint = Paint()
      ..color = MidnightHacker.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlX = p1.dx + (p2.dx - p1.dx) / 2;
      path.cubicTo(controlX, p1.dy, controlX, p2.dy, p2.dx, p2.dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw points dots
    final dotPaint = Paint()
      ..color = MidnightHacker.positive
      ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Bar Chart Card ──
class _BarChartCard extends StatelessWidget {
  const _BarChartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 115,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: MidnightHacker.dimGreen),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THREAT ENCOUNTER DENSITIES BY SEVERITY',
            style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 9),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarChartPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final values = [4, 12, 28, 45]; // Critical, High, Medium, Low
    final labels = ['CRIT', 'HIGH', 'MED', 'LOW'];
    final colors = [
      const Color(0xFFFF3B30), // Red
      const Color(0xFFFF9500), // Orange
      const Color(0xFFFFCC00), // Yellow
      MidnightHacker.primary, // Green
    ];

    final maxVal = values.reduce(max);
    final barCount = values.length;
    final totalSpacing = size.width * 0.2;
    final barWidth = (size.width - totalSpacing) / barCount;
    final spacing = totalSpacing / (barCount + 1);

    for (int i = 0; i < barCount; i++) {
      final val = values[i];
      final barHeight = (size.height - 24) * (val / maxVal);
      final x = spacing + i * (barWidth + spacing);
      final y = size.height - 14 - barHeight;

      // Draw Bar
      final paint = Paint()
        ..color = colors[i].withOpacity(0.85)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), paint);

      // Draw Bar Border
      final borderPaint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), borderPaint);

      // Label at bottom
      final labelSpan = TextSpan(
        text: labels[i],
        style: const TextStyle(
          color: MidnightHacker.dimGreen,
          fontFamily: 'monospace',
          fontSize: 7,
        ),
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(x + (barWidth - labelPainter.width) / 2, size.height - 12),
      );

      // Value at top
      final valSpan = TextSpan(
        text: val.toString(),
        style: TextStyle(
          color: colors[i],
          fontFamily: 'monospace',
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      );
      final valPainter = TextPainter(
        text: valSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      valPainter.paint(
        canvas,
        Offset(x + (barWidth - valPainter.width) / 2, y - 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Cyber-Attack Simulation Card ──
class _CyberAttackSimulationCard extends StatefulWidget {
  const _CyberAttackSimulationCard();

  @override
  State<_CyberAttackSimulationCard> createState() => _CyberAttackSimulationCardState();
}

class _CyberAttackSimulationCardState extends State<_CyberAttackSimulationCard> with TickerProviderStateMixin {
  late final AnimationController _animController;
  final Random _random = Random();
  final List<_AttackFlow> _activeAttacks = [];
  final List<Offset> _landPoints = [];

  static const List<String> _worldMapData = [
    "                                                                                                    ",
    "          ..                                                                                        ",
    "         ....                                                                                       ",
    "       ........                                          ..                                         ",
    "      ..........          ...                          ......                                       ",
    "     ............       .......                       ........                                      ",
    "    ..............    ...........                   ...........                                     ",
    "   ................  .............                 .............              ...                   ",
    "  ................................                 ..............            .....                  ",
    "  .................................               ................          .......                 ",
    "   ...............................                ................         .........                ",
    "    .............................                 ................         .........                ",
    "     ..........................                    ..............           .......                 ",
    "       ......................                       ............             .....                  ",
    "        ...................                          ..........               ...                   ",
    "          ...............                             ........                                      ",
    "            ...........                                ......               ...                     ",
    "             .........                                  ....               .....                    ",
    "               .....                                     ..                 ...                     ",
    "                ...                                                                                 ",
    "                 .                                                                                  ",
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    // Parse map grid
    for (int y = 0; y < _worldMapData.length; y++) {
      for (int x = 0; x < _worldMapData[y].length; x++) {
        if (_worldMapData[y][x] == '.') {
          _landPoints.add(Offset(x / 100.0, y / 21.0)); // Normalized coordinates
        }
      }
    }

    // Generate random attacks periodically
    Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) return;
      _spawnAttack();
    });
  }

  void _spawnAttack() {
    if (_landPoints.isEmpty) return;

    // Pick random land points
    final src = _landPoints[_random.nextInt(_landPoints.length)];
    final dst = _landPoints[_random.nextInt(_landPoints.length)];

    final attack = _AttackFlow(
      source: src,
      destination: dst,
      createdAt: DateTime.now(),
      color: _random.nextBool() ? MidnightHacker.primary : const Color(0xFFFF3B30),
    );

    setState(() {
      _activeAttacks.add(attack);
      if (_activeAttacks.length > 20) {
        _activeAttacks.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: MidnightHacker.dimGreen),
        color: MidnightHacker.background,
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_outlined, color: MidnightHacker.dimGreen, size: 16),
              const SizedBox(width: 8),
              Text(
                'LIVE GLOBAL CYBER-ATTACK SIMULATION',
                style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 9),
              ),
              const Spacer(),
              _LiveIndicator(),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRect(
              child: Stack(
                children: [
                  // Map layer
                  SizedBox.expand(
                    child: CustomPaint(
                      painter: _WorldMapPainter(_landPoints),
                    ),
                  ),
                  // Attack animations layer
                  SizedBox.expand(
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _AttackFlowPainter(_activeAttacks),
                        );
                      },
                    ),
                  ),
                  // Scanline overlay
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: MidnightHacker.primary.withOpacity(0.3)),
                          gradient: LinearGradient(
                            colors: [
                              MidnightHacker.background.withOpacity(0.9),
                              Colors.transparent,
                              Colors.transparent,
                              MidnightHacker.background.withOpacity(0.9),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.15, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldMapPainter extends CustomPainter {
  final List<Offset> landPoints;
  _WorldMapPainter(this.landPoints);

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = MidnightHacker.dimGreen.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    // Draw dots for landmasses
    for (var point in landPoints) {
      final x = point.dx * size.width;
      final y = point.dy * size.height;
      canvas.drawCircle(Offset(x, y), 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AttackFlowPainter extends CustomPainter {
  final List<_AttackFlow> attacks;
  _AttackFlowPainter(this.attacks);

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();

    for (var attack in attacks) {
      final age = now.difference(attack.createdAt).inMilliseconds;
      if (age > 2000) continue; // Lifespan of 2 seconds

      final progress = (age / 1000).clamp(0.0, 1.0); // Line drawing progress
      final fade = (1.0 - (age / 2000)).clamp(0.0, 1.0); // Global fade

      final src = Offset(attack.source.dx * size.width, attack.source.dy * size.height);
      final dst = Offset(attack.destination.dx * size.width, attack.destination.dy * size.height);

      // Draw bezier arc
      final paintLine = Paint()
        ..color = attack.color.withOpacity(fade * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final path = Path();
      path.moveTo(src.dx, src.dy);
      
      // Control point logic to curve the path upward
      final midX = src.dx + (dst.dx - src.dx) / 2;
      final midY = src.dy + (dst.dy - src.dy) / 2;
      // Arc height depends on distance
      final distance = (src - dst).distance;
      final ctrlX = midX;
      final ctrlY = midY - (distance * 0.3); // Arch up

      // Calculate the current endpoint based on progress
      // Using quadratic bezier interpolation formula
      final t = progress;
      final currentX = pow(1 - t, 2) * src.dx + 2 * (1 - t) * t * ctrlX + pow(t, 2) * dst.dx;
      final currentY = pow(1 - t, 2) * src.dy + 2 * (1 - t) * t * ctrlY + pow(t, 2) * dst.dy;

      // Draw partial path
      // To draw a partial bezier in canvas, we just use a quadTo to the interpolated point
      // It's a simplification but visually works well for fast animations
      path.quadraticBezierTo(
        src.dx + (ctrlX - src.dx) * t, 
        src.dy + (ctrlY - src.dy) * t, 
        currentX, 
        currentY
      );
      
      canvas.drawPath(path, paintLine);

      // Origin dot
      final srcPaint = Paint()
        ..color = attack.color.withOpacity(fade)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(src, 3, srcPaint);

      // Impact ripple
      if (progress >= 1.0) {
        final rippleProgress = ((age - 1000) / 1000).clamp(0.0, 1.0);
        final ripplePaint = Paint()
          ..color = attack.color.withOpacity(fade * (1 - rippleProgress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(dst, 4 + (16 * rippleProgress), ripplePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _AttackFlow {
  final Offset source;
  final Offset destination;
  final DateTime createdAt;
  final Color color;

  _AttackFlow({
    required this.source,
    required this.destination,
    required this.createdAt,
    required this.color,
  });
}

class _LiveIndicator extends StatefulWidget {
  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text('LIVE', style: MidnightHacker.monoSmall.copyWith(color: const Color(0xFFFF3B30), fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}


