import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/bom_exporter.dart';
import '../core/models.dart';
import '../data/project_repo.dart';
import '../data/repo_factory.dart';
import 'standards_manager_screen.dart';
import 'widgets/bom_scaffold.dart';
import 'widgets/glass_container.dart';

class ProjectScreen extends StatefulWidget {
  final int initialCount;
  final List<WorkLocation>? loaded;
  final String? name;
  const ProjectScreen({
    super.key,
    required this.initialCount,
    this.loaded,
    this.name,
  });

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late List<WorkLocation> locations;
  String? _name;

  @override
  void initState() {
    super.initState();
    locations = widget.loaded ??
        List.generate(widget.initialCount, (_) => WorkLocation());
    _name = widget.name;
  }

  Future<void> _addLocation() async {
    setState(() => locations.add(WorkLocation()));
  }

  Future<void> _removeLocation(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete work location?'),
        content: const Text(
          'Removing this location will also discard any standards or values you\'ve configured for it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
    final repo = await createRepo();
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
    final theme = Theme.of(context);
    return BomScaffold(
      appBar: AppBar(
        title: Text(_name ?? 'Project workspace'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download_outlined),
            onPressed: _exportCsv,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: FilledButton.icon(
              onPressed: _saveProject,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save project'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: locations.isEmpty
            ? Center(
                child: GlassContainer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.room_preferences,
                          size: 46, color: theme.colorScheme.secondary),
                      const SizedBox(height: 16),
                      Text(
                        'No locations yet',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add work locations to begin assigning standards and tracking materials.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                itemCount: locations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final loc = locations[index];
                  final applied = loc.standards.length;
                  return GlassContainer(
                    key: ValueKey(loc),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Work location ${index + 1}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Remove location',
                              onPressed: () => _removeLocation(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey('barcode_$index'),
                          initialValue: loc.barcode,
                          decoration: const InputDecoration(
                            labelText: 'Barcode',
                            hintText: 'Scan or enter a barcode reference',
                          ),
                          onChanged: (v) => loc.barcode = v,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white.withOpacity(0.03),
                            border:
                                Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.fact_check_outlined,
                                  color: theme.colorScheme.secondary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Standards applied',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      applied == 0
                                          ? 'No standards attached yet. Configure to get tailored components.'
                                          : '$applied standard${applied == 1 ? '' : 's'} selected.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: () => _openStandards(index),
                                child: const Text('Configure'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add work location'),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final repo = await createRepo();
    final standards = await repo.listStandards();
    final flaggedMaterials = await repo.loadFlaggedMaterials();
    final globalDynamicComponents =
        await repo.loadGlobalDynamicComponents();
    final exporter = BomExporter();
    final csv = exporter.buildCsv(
      locations,
      standards,
      flaggedMaterials: flaggedMaterials,
      globalDynamicComponents: globalDynamicComponents,
    );
    const csvTypeGroup = XTypeGroup(
      label: 'CSV',
      extensions: <String>['csv'],
      mimeTypes: <String>['text/csv'],
    );
    final String suggestedName = _buildExportFileName();
    try {
      final FileSaveLocation? location = await getSaveLocation(
        acceptedTypeGroups: <XTypeGroup>[csvTypeGroup],
        suggestedName: suggestedName,
      );
      if (location == null) {
        return;
      }

      final Uint8List bytes = Uint8List.fromList(utf8.encode(csv));
      final XFile file = XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name: suggestedName,
      );

      var path = location.path;
      if (path.isNotEmpty && !path.toLowerCase().endsWith('.csv')) {
        path = '$path.csv';
      }

      await file.saveTo(path);
      if (!mounted) return;
      final String message =
          path.isEmpty ? 'Exported BOM CSV' : 'Exported BOM CSV to $path';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $error')),
      );
    }
  }

  String _buildExportFileName() {
    final String rawName =
        (_name?.trim().isNotEmpty ?? false) ? _name!.trim() : 'bom_export';
    final sanitized = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final collapsed = sanitized.replaceAll(RegExp(r'_+'), '_');
    final trimmed = collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
    final base = trimmed.isEmpty ? 'bom_export' : trimmed;
    return '$base.csv';
  }

  Future<void> _saveProject() async {
    final repo = LocalProjectRepo();
    if (_name == null || _name!.isEmpty) {
      final controller = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Project name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter a project name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty) return;
      _name = name;
    }
    final proj = Project(name: _name!, locations: locations);
    await repo.saveProject(proj);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project saved')),
      );
    }
    setState(() {});
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
      final std = available.firstWhere((s) => s.code == code,
          orElse: () => StandardDef(code: code, name: ''));
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
    final repo = await createRepo();
    final list = await repo.listStandards();
    setState(() => available = list);
  }

  Widget _buildParamField(ParameterDef p) {
    final label = p.unit == null ? p.key : '${p.key} (${p.unit})';
    switch (p.type) {
      case ParamType.boolean:
        return SwitchListTile(
          value: (vars[p.key] as bool?) ?? false,
          title: Text(label),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          onChanged: (v) => setState(() => vars[p.key] = v),
        );
      case ParamType.enumType:
        return DropdownButtonFormField<String>(
          key: ValueKey(p.key),
          decoration: InputDecoration(labelText: label),
          value: vars[p.key] as String?,
          items: p.allowedValues
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => vars[p.key] = v),
        );
      case ParamType.number:
        return TextFormField(
          key: ValueKey(p.key),
          initialValue: vars[p.key]?.toString() ?? '',
          decoration: InputDecoration(labelText: label),
          keyboardType: TextInputType.number,
          onChanged: (v) => vars[p.key] = double.tryParse(v),
        );
      case ParamType.text:
      default:
        return TextFormField(
          key: ValueKey(p.key),
          initialValue: vars[p.key]?.toString() ?? '',
          decoration: InputDecoration(labelText: label),
          onChanged: (v) => vars[p.key] = v,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = _gatherParams();
    return BomScaffold(
      appBar: AppBar(
        title: const Text('Apply Standards'),
        actions: [
          IconButton(
            tooltip: 'Open standards manager',
            icon: const Icon(Icons.library_add_outlined),
            onPressed: _manageStandards,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop({
                'standards': selected,
                'variables': vars,
              }),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Done'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: ListView(
          children: [
            GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected standards',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selected.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withOpacity(0.03),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: theme.colorScheme.secondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No standards yet. Add at least one to configure this location.',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ...selected.map((code) {
                      final std = available.firstWhere(
                        (s) => s.code == code,
                        orElse: () => StandardDef(code: code, name: ''),
                      );
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.03),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${std.code} — ${std.name}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    std.parameters.isEmpty
                                        ? 'No parameters required.'
                                        : '${std.parameters.length} parameter${std.parameters.length == 1 ? '' : 's'} required.',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove standard',
                              onPressed: () => setState(() {
                                selected.remove(code);
                                _pruneVars();
                              }),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _addStandard,
                    icon: const Icon(Icons.add),
                    label: const Text('Add standard'),
                  ),
                ],
              ),
            ),
            if (params.isNotEmpty) const SizedBox(height: 24),
            if (params.isNotEmpty)
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Variable inputs',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...params.map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildParamField(p),
                        )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
