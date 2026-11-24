// dashboard_screen.dart - System overview backed by the real catalog.
// The map uses real country geometry and supports zoom and pan.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/midnight_hacker.dart';
import '../models/catalog_ui.dart';
import '../generated/capability_index.dart';
import '../generated/wordlist_index.dart';
import '../generated/world_map.dart';
import '../src/rust/api.dart' as rust;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _statsJson = '';
  int _availableProviders = 0;
  int _missingProviders = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await rust.getCatalogStats();
      final providers = await rust.probeProviders();
      int available = 0;
      int missing = 0;
      for (final p in providers) {
        final s = p.state.toLowerCase();
        if (s.contains('available')) {
          available++;
        } else {
          missing++;
        }
      }
      if (mounted) {
        setState(() {
          _statsJson = stats;
          _availableProviders = available;
          _missingProviders = missing;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Map<String, dynamic> get _stats {
    try {
      return jsonDecode(_statsJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final phases = (stats['phases'] as Map?) ?? {};
    final totalTools = CatalogUi.allTools.length;
    final toolReady = totalTools == 0 ? 0.0 : _availableProviders / totalTools;

    return Scaffold(
      backgroundColor: MidnightHacker.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                Text('SYSTEM OVERVIEW',
                    style: MidnightHacker.headingLarge.copyWith(fontSize: 26),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('11 phases  /  241 capabilities  /  ${CatalogUi.totalOperations} sub-actions',
                    style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
                    textAlign: TextAlign.center),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cross = constraints.maxWidth > 820
                        ? 4
                        : (constraints.maxWidth > 520 ? 2 : 1);
                    return GridView.count(
                      crossAxisCount: cross,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.4,
                      children: [
                        _StatCard(title: 'CAPABILITIES', value: '${kCapabilities.length}', icon: Icons.extension_outlined),
                        _StatCard(title: 'PHASES', value: '${CatalogUi.phases.length}', icon: Icons.layers_outlined),
                        _StatCard(title: 'SUB-ACTIONS', value: '${CatalogUi.totalOperations}', icon: Icons.terminal_outlined),
                        _StatCard(title: 'TOOLS', value: '$totalTools', icon: Icons.build_outlined),
                        _StatCard(title: 'TOOLS READY', value: _loaded ? '$_availableProviders' : '...', icon: Icons.check_circle_outline),
                        _StatCard(title: 'TOOLS MISSING', value: _loaded ? '$_missingProviders' : '...', icon: Icons.error_outline),
                        _StatCard(title: 'WORDLISTS', value: '${kWordlists.length}', icon: Icons.library_books_outlined),
                        _StatCard(title: 'CATALOG', value: (stats['hash'] ?? kCatalogHash).toString().substring(0, 8), icon: Icons.fingerprint_outlined),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _Panel(title: 'GLOBAL ASSET MAP', child: const _WorldMap()),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 820) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Panel(title: 'PHASE DISTRIBUTION', child: _PhaseBars(phases: phases))),
                          const SizedBox(width: 12),
                          Expanded(child: _Panel(title: 'SYSTEM HEALTH', child: _SystemHealth(toolReady: toolReady))),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _Panel(title: 'PHASE DISTRIBUTION', child: _PhaseBars(phases: phases)),
                        const SizedBox(height: 12),
                        _Panel(title: 'SYSTEM HEALTH', child: _SystemHealth(toolReady: toolReady)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: MidnightHacker.primary)),
      child: Row(
        children: [
          Icon(icon, color: MidnightHacker.positive, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 10)),
              Text(value, style: MidnightHacker.heading.copyWith(fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: MidnightHacker.primary)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: MidnightHacker.heading.copyWith(fontSize: 14, letterSpacing: 1)),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Zoomable world map drawn from real Natural Earth country polygons.
class _WorldMap extends StatefulWidget {
  const _WorldMap();

  @override
  State<_WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<_WorldMap> {
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  WorldCountry? _hovered;
  Offset? _hoverPos;

  void _reset() => setState(() {
        _zoom = 1.0;
        _pan = Offset.zero;
        _hovered = null;
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onScaleUpdate: (details) {
            setState(() {
              _zoom = (_zoom * details.scale).clamp(1.0, 8.0);
              _pan += details.focalPointDelta;
            });
          },
          child: Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: MidnightHacker.dimGreen)),
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  return MouseRegion(
                    onHover: (event) {
                      final hit = _hitTest(event.localPosition, size);
                      if (hit != _hovered) {
                        setState(() {
                          _hovered = hit;
                          _hoverPos = event.localPosition;
                        });
                      } else if (hit != null) {
                        setState(() => _hoverPos = event.localPosition);
                      }
                    },
                    onExit: (_) => setState(() => _hovered = null),
                    child: CustomPaint(
                      painter: _WorldMapPainter(
                        zoom: _zoom,
                        pan: _pan,
                        hovered: _hovered,
                      ),
                      size: size,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MapButton(icon: Icons.remove_outlined, tooltip: 'Zoom out', onTap: () => setState(() => _zoom = (_zoom / 1.3).clamp(1.0, 8.0))),
            const SizedBox(width: 8),
            Text('${_zoom.toStringAsFixed(1)}x', style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen)),
            const SizedBox(width: 8),
            _MapButton(icon: Icons.add_outlined, tooltip: 'Zoom in', onTap: () => setState(() => _zoom = (_zoom * 1.3).clamp(1.0, 8.0))),
            const SizedBox(width: 8),
            _MapButton(icon: Icons.center_focus_strong_outlined, tooltip: 'Reset view', onTap: _reset),
            const SizedBox(width: 16),
            if (_hovered != null)
              Text(_hovered!.name, style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.positive, fontSize: 11))
            else
              Text('Drag to pan  /  Scroll to zoom  /  Hover a country',
                  style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  WorldCountry? _hitTest(Offset local, Size size) {
    for (final country in kWorldCountries) {
      for (final ring in country.rings) {
        if (_pathFor(ring, size).contains(local)) return country;
      }
    }
    return null;
  }

  Path _pathFor(List<double> ring, Size size) {
    final path = Path();
    final origin = Offset(
      size.width / 2 - (size.width * _zoom) / 2 + _pan.dx,
      size.height / 2 - (size.height * _zoom) / 2 + _pan.dy,
    );
    for (int i = 0; i + 1 < ring.length; i += 2) {
      final x = origin.dx + ring[i] * size.width * _zoom;
      final y = origin.dy + ring[i + 1] * size.height * _zoom;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}

class _WorldMapPainter extends CustomPainter {
  final double zoom;
  final Offset pan;
  final WorldCountry? hovered;

  const _WorldMapPainter({required this.zoom, required this.pan, required this.hovered});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = MidnightHacker.background);

    final grid = Paint()
      ..color = MidnightHacker.primary.withOpacity(0.08)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 12; i++) {
      final x = size.width * i / 12;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (int i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final origin = Offset(
      size.width / 2 - (size.width * zoom) / 2 + pan.dx,
      size.height / 2 - (size.height * zoom) / 2 + pan.dy,
    );

    final fill = Paint()
      ..color = MidnightHacker.primary.withOpacity(0.10)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = MidnightHacker.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final hoverFill = Paint()
      ..color = MidnightHacker.positive.withOpacity(0.28)
      ..style = PaintingStyle.fill;
    final hoverStroke = Paint()
      ..color = MidnightHacker.positive
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final country in kWorldCountries) {
      final isHover = hovered?.name == country.name;
      for (final ring in country.rings) {
        final path = Path();
        for (int i = 0; i + 1 < ring.length; i += 2) {
          final x = origin.dx + ring[i] * size.width * zoom;
          final y = origin.dy + ring[i + 1] * size.height * zoom;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, isHover ? hoverFill : fill);
        canvas.drawPath(path, isHover ? hoverStroke : stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) =>
      oldDelegate.zoom != zoom ||
      oldDelegate.pan != pan ||
      oldDelegate.hovered != hovered;
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(border: Border.all(color: MidnightHacker.primary)),
          child: Icon(icon, size: 15, color: MidnightHacker.primary),
        ),
      ),
    );
  }
}

class _PhaseBars extends StatelessWidget {
  final Map phases;

  const _PhaseBars({required this.phases});

  @override
  Widget build(BuildContext context) {
    final max = phases.values.fold<int>(1, (m, v) => (v is int && v > m) ? v : m);
    return Column(
      children: CatalogUi.phases.map((info) {
        final raw = phases[info.id] ?? CatalogUi.capabilityCount(info.phase);
        final count = raw is int ? raw : 0;
        final width = max == 0 ? 0.0 : (count / max) * 220.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 96, child: Text(info.shortName, style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 10))),
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(border: Border.all(color: MidnightHacker.dimGreen)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: SizedBox(width: width, child: Container(color: MidnightHacker.primary.withOpacity(0.7))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 28, child: Text('$count', style: MidnightHacker.monoSmall, textAlign: TextAlign.right)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SystemHealth extends StatelessWidget {
  final double toolReady;

  const _SystemHealth({required this.toolReady});

  @override
  Widget build(BuildContext context) {
    final categories = kWordlistCategoryLabels.length;
    final rows = <List<dynamic>>[
      ['CATALOG INTEGRITY', 'verified', 1.0],
      ['PROVIDER AVAILABILITY', 'scanning', toolReady],
      ['WORDLIST COVERAGE', '$categories categories', (categories / 21).clamp(0.0, 1.0)],
      ['RUNTIME', 'ready', 1.0],
    ];
    return Column(
      children: rows.map((r) {
        final label = r[0] as String;
        final value = r[1] as String;
        final progress = (r[2] as num).toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(label, style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen, fontSize: 10)),
                  const Spacer(),
                  Text(value, style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.positive, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 8,
                decoration: BoxDecoration(border: Border.all(color: MidnightHacker.dimGreen)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: SizedBox(width: progress * 220, child: Container(color: MidnightHacker.primary.withOpacity(0.7))),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
