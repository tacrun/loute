import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../themes/midnight_hacker.dart';
import '../../generated/capability_index.dart';

/// Capability Explorer — searchable catalog with facets per 1-5-5.md §11.1.
/// Phase · provider · availability · risk · noise · network · MITRE facets.
class CapabilityExplorerScreen extends ConsumerStatefulWidget {
  const CapabilityExplorerScreen({super.key});

  @override
  ConsumerState<CapabilityExplorerScreen> createState() =>
      _CapabilityExplorerScreenState();
}

class _CapabilityExplorerScreenState
    extends ConsumerState<CapabilityExplorerScreen> {
  String _searchQuery = '';
  String? _selectedPhase;
  String? _selectedRisk;
  String? _selectedAvailability;

  final List<String> _phases = LoutePhase.values.map((p) => p.name).toList();
  final List<String> _risks = ['r0', 'r1', 'r2', 'r3', 'r4'];
  final List<String> _availabilities = ['available', 'missing', 'probing'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightHacker.background,
      appBar: AppBar(
        title: const Text('CAPABILITY EXPLORER'),
        backgroundColor: MidnightHacker.background,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: MidnightHacker.monoStyle,
              decoration: InputDecoration(
                hintText: 'Search capabilities...',
                prefixIcon: const Icon(Icons.search, color: MidnightHacker.primary),
                border: MidnightHacker.inputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          // Facet filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                _buildFacetChip('Phase', _selectedPhase, _phases, (v) {
                  setState(() => _selectedPhase = v);
                }),
                _buildFacetChip('Risk', _selectedRisk, _risks, (v) {
                  setState(() => _selectedRisk = v);
                }),
                _buildFacetChip('Availability', _selectedAvailability, _availabilities, (v) {
                  setState(() => _selectedAvailability = v);
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Stats bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  '${CatalogMeta.totalCapabilities} capabilities · ${CatalogMeta.totalPhases} phases',
                  style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
                ),
                const Spacer(),
                Text(
                  'LOUTE V${CatalogMeta.version}',
                  style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.positive),
                ),
              ],
            ),
          ),
          const Divider(color: MidnightHacker.primary),
          // Capability list
          Expanded(
            child: _buildCapabilityList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFacetChip(
    String label,
    String? selected,
    List<String> options,
    void Function(String?) onSelect,
  ) {
    return PopupMenuButton<String>(
      onSelected: (v) => onSelect(v == selected ? null : v),
      itemBuilder: (context) => options
          .map((o) => PopupMenuItem(value: o, child: Text(o, style: MidnightHacker.monoSmall)))
          .toList(),
      child: Chip(
        label: Text(
          selected != null ? '$label: $selected' : label,
          style: MidnightHacker.monoSmall,
        ),
        backgroundColor: MidnightHacker.background,
        side: const BorderSide(color: MidnightHacker.primary, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  Widget _buildCapabilityList() {
    // Show a placeholder list — in production this would come from the Rust API
    final phases = LoutePhase.values;
    return ListView.builder(
      itemCount: phases.length,
      itemBuilder: (context, index) {
        final phase = phases[index];
        final count = CatalogMeta.phaseCounts[phase.name] ?? 0;
        return ExpansionTile(
          title: Text(
            '${phase.displayName} ($count)',
            style: MidnightHacker.heading.copyWith(fontSize: 16),
          ),
          iconColor: MidnightHacker.primary,
          collapsedIconColor: MidnightHacker.primary,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: Text(
                '$count capabilities in this phase',
                style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
              ),
            ),
          ],
        );
      },
    );
  }
}
