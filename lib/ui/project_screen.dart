import 'package:flutter/material.dart';
import '../core/models.dart';
import '../data/repo_factory.dart';
import '../core/bom_exporter.dart';
import 'standards_manager_screen.dart';

class ProjectScreen extends StatefulWidget {
  final int initialCount;
  const ProjectScreen({
    super.key,
    required this.initialCount,
  });

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late List<WorkLocation> locations;

  @override
  void initState() {
    super.initState();
    locations = List.generate(widget.initialCount, (_) => WorkLocation());
  }

  Future<void> _addLocation() async {
    setState(() => locations.add(WorkLocation()));
  }

  Future<void> _removeLocation(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete work location?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirm == true) {
      setState(() => locations.removeAt(index));
    }
  }

  Future<void> _openStandards(int index) async {
    final repo = createRepo();
    final allStds = await repo.listStandards();
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => LocationStandardsScreen(
          available: allStds,
          selected: locations[index].standards,
          variables: locations[index].variables,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        locations[index].standards =
            (result['standards'] as Set).cast<String>();
        locations[index].variables =
            Map<String, dynamic>.from(result['variables'] as Map);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final loc = locations[index];
          return ListTile(
            key: ValueKey(loc),
            title: TextFormField(
              key: ValueKey('barcode_$index'),
              initialValue: loc.barcode,
              decoration: const InputDecoration(labelText: 'Barcode'),
              onChanged: (v) => loc.barcode = v,
            ),
            subtitle: Text(
              loc.standards.isEmpty
                  ? 'No standards'
                  : '${loc.standards.length} standard${loc.standards.length == 1 ? '' : 's'}',
            ),
            onTap: () => _openStandards(index),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _removeLocation(index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLocation,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final repo = createRepo();
    final standards = await repo.listStandards();
    final exporter = BomExporter();
    final csv = exporter.buildCsv(locations, standards);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('BOM CSV'),
        content: SingleChildScrollView(
          child: SelectableText(csv),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class LocationStandardsScreen extends StatefulWidget {
  final List<StandardDef> available;
  final Set<String> selected;
  final Map<String, dynamic> variables;
  const LocationStandardsScreen({
    super.key,
    required this.available,
    required this.selected,
    required this.variables,
  });

  @override
  State<LocationStandardsScreen> createState() =>
      _LocationStandardsScreenState();
}

class _LocationStandardsScreenState extends State<LocationStandardsScreen> {
  late Set<String> selected;
  late Map<String, dynamic> vars;
  late List<StandardDef> available;

  @override
  void initState() {
    super.initState();
    selected = Set.of(widget.selected);
    vars = Map<String, dynamic>.from(widget.variables);
    available = widget.available;
  }

  List<ParameterDef> _gatherParams() {
    final map = <String, ParameterDef>{};
    for (final code in selected) {
      final std = available.firstWhere((s) => s.code == code, orElse: () =>
          StandardDef(code: code, name: ''));
      for (final p in std.parameters) {
        map[p.key] = p;
      }
    }
    return map.values.toList();
  }

  void _pruneVars() {
    final keys = _gatherParams().map((e) => e.key).toSet();
    vars.removeWhere((k, _) => !keys.contains(k));
  }

  Future<void> _addStandard() async {
    final choices =
        available.where((s) => !selected.contains(s.code)).toList();
    if (choices.isEmpty) return;
    final code = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Add Standard'),
        children: choices
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, s.code),
                child: Text('${s.code} — ${s.name}'),
              ),
            )
            .toList(),
      ),
    );
    if (code != null) {
      setState(() {
        selected.add(code);
        _pruneVars();
      });
    }
  }

  Future<void> _manageStandards() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StandardsManagerScreen()),
    );
    final repo = createRepo();
    final list = await repo.listStandards();
    setState(() => available = list);
  }

  Widget _buildParamField(ParameterDef p) {
    final label = p.unit == null ? p.key : '${p.key} (${p.unit})';
    switch (p.type) {
      case ParamType.boolean:
        return SwitchListTile(
          title: Text(label),
          value: (vars[p.key] as bool?) ?? false,
          onChanged: (v) => setState(() => vars[p.key] = v),
        );
      case ParamType.enumType:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<String>(
            key: ValueKey(p.key),
            decoration: InputDecoration(labelText: label),
            value: vars[p.key] as String?,
            items: p.allowedValues
                .map(
                  (v) => DropdownMenuItem(value: v, child: Text(v)),
                )
                .toList(),
            onChanged: (v) => setState(() => vars[p.key] = v),
          ),
        );
      case ParamType.number:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextFormField(
            key: ValueKey(p.key),
            initialValue: vars[p.key]?.toString() ?? '',
            decoration: InputDecoration(labelText: label),
            keyboardType: TextInputType.number,
            onChanged: (v) => vars[p.key] = double.tryParse(v),
          ),
        );
      case ParamType.text:
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextFormField(
            key: ValueKey(p.key),
            initialValue: vars[p.key]?.toString() ?? '',
            decoration: InputDecoration(labelText: label),
            onChanged: (v) => vars[p.key] = v,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = _gatherParams();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply Standards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_add),
            onPressed: _manageStandards,
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop({
              'standards': selected,
              'variables': vars,
            }),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        children: [
          ...selected.map((code) {
            final std = available.firstWhere(
                (s) => s.code == code,
                orElse: () => StandardDef(code: code, name: ''));
            return ListTile(
              title: Text('${std.code} — ${std.name}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => setState(() {
                  selected.remove(code);
                  _pruneVars();
                }),
              ),
            );
          }),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add Standard'),
            onTap: _addStandard,
          ),
          if (params.isNotEmpty) const Divider(),
          ...params.map(_buildParamField),
        ],
      ),
    );
  }
}
