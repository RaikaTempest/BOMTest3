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
          assignments: [
            for (final assignment in locations[index].assignments)
              assignment.copy(),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        final rawAssignments = result['assignments'];
        if (rawAssignments is List) {
          final updated = <StandardAssignment>[];
          for (final entry in rawAssignments) {
            if (entry is StandardAssignment) {
              updated.add(entry.copy());
            } else if (entry is Map) {
              updated.add(
                StandardAssignment.fromJson(
                  entry.cast<String, dynamic>(),
                ),
              );
            }
          }
          locations[index].assignments = updated;
        }
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
                  final applied = loc.assignments.length;
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
    final exporter = BomExporter();
    final csv = exporter.buildCsv(
      locations,
      standards,
      flaggedMaterials: flaggedMaterials,
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

class _StandardSelectionDialog extends StatefulWidget {
  final List<StandardDef> choices;

  const _StandardSelectionDialog({required this.choices});

  @override
  State<_StandardSelectionDialog> createState() =>
      _StandardSelectionDialogState();
}

class _StandardSelectionDialogState extends State<_StandardSelectionDialog> {
  late final TextEditingController _search;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _categoryLabel(StandardDef std) {
    final value = std.category.trim();
    return value.isEmpty ? 'Misc.' : value;
  }

  Iterable<Widget> _buildListTiles(
    BuildContext context,
    List<MapEntry<String, List<StandardDef>>> groups,
  ) sync* {
    final theme = Theme.of(context);
    for (final entry in groups) {
      yield Container(
        width: double.infinity,
        color: theme.colorScheme.surfaceVariant,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Text(
          entry.key,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
      for (final std in entry.value) {
        yield ListTile(
          dense: true,
          title: Text('${std.code} — ${std.name}'),
          onTap: () => Navigator.of(context).pop(std),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowerQuery = _query.toLowerCase();
    final filtered = widget.choices.where((s) {
      if (lowerQuery.isEmpty) return true;
      return s.code.toLowerCase().contains(lowerQuery) ||
          s.name.toLowerCase().contains(lowerQuery);
    }).toList()
      ..sort((a, b) {
        final categoryA = _categoryLabel(a).toLowerCase();
        final categoryB = _categoryLabel(b).toLowerCase();
        final categoryCompare = categoryA.compareTo(categoryB);
        if (categoryCompare != 0) return categoryCompare;
        return a.code.toLowerCase().compareTo(b.code.toLowerCase());
      });

    final grouped = <String, List<StandardDef>>{};
    for (final std in filtered) {
      final category = _categoryLabel(std);
      grouped.putIfAbsent(category, () => []).add(std);
    }
    final groupEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return AlertDialog(
      title: const Text('Add Standard'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search standards',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() {
                _query = value.trim();
              }),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: filtered.isEmpty
                  ? const Center(child: Text('No standards match your search.'))
                  : ListView(
                      padding: EdgeInsets.zero,
                      children:
                          _buildListTiles(context, groupEntries).toList(),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class LocationStandardsScreen extends StatefulWidget {
  final List<StandardDef> available;
  final List<StandardAssignment> assignments;
  const LocationStandardsScreen({
    super.key,
    required this.available,
    required this.assignments,
  });

  @override
  State<LocationStandardsScreen> createState() =>
      _LocationStandardsScreenState();
}

class _LocationStandardsScreenState extends State<LocationStandardsScreen> {
  late List<StandardAssignment> assignments;
  late List<StandardDef> available;
  final Map<String, dynamic> _sharedVariables = {};
  final Map<String, int> _parameterUsageCounts = {};
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    assignments = widget.assignments.map((e) => e.copy()).toList();
    available = widget.available;
    _hydrateAssignments();
    _refreshSharedParameters();
  }

  void _hydrateAssignments() {
    for (final assignment in assignments) {
      final std = _findStandard(assignment);
      if (std != null) {
        _syncAssignment(assignment, std);
      }
    }
  }

  void _refreshSharedParameters() {
    final previousShared = Map<String, dynamic>.from(_sharedVariables);
    final usageCounts = <String, int>{};
    final firstValues = <String, dynamic>{};
    final Map<StandardAssignment, Set<String>> assignmentKeys = {};

    for (final assignment in assignments) {
      final keysForAssignment = <String>{};
      final std = _findStandard(assignment);
      if (std != null) {
        for (final param in std.parameters) {
          keysForAssignment.add(param.key);
        }
      } else {
        keysForAssignment.addAll(assignment.variables.keys);
      }
      assignmentKeys[assignment] = keysForAssignment;
      for (final key in keysForAssignment) {
        usageCounts[key] = (usageCounts[key] ?? 0) + 1;
        if (!firstValues.containsKey(key) &&
            assignment.variables.containsKey(key)) {
          firstValues[key] = assignment.variables[key];
        }
      }
    }

    final keysToDispose = previousShared.keys
        .where((key) => !usageCounts.containsKey(key))
        .toList();
    final newShared = <String, dynamic>{};
    for (final key in usageCounts.keys) {
      if (firstValues.containsKey(key)) {
        newShared[key] = firstValues[key];
      } else if (previousShared.containsKey(key)) {
        newShared[key] = previousShared[key];
      } else {
        newShared[key] = null;
      }
    }

    setState(() {
      _parameterUsageCounts
        ..clear()
        ..addAll(usageCounts);
      _sharedVariables
        ..clear()
        ..addAll(newShared);

      for (final entry in assignmentKeys.entries) {
        final assignment = entry.key;
        final keysForAssignment = entry.value;
        for (final key in keysForAssignment) {
          if (!_sharedVariables.containsKey(key)) {
            assignment.variables.remove(key);
            continue;
          }
          final value = _sharedVariables[key];
          if (value == null) {
            assignment.variables.remove(key);
          } else {
            assignment.variables[key] = value;
          }
        }
      }
    });

    for (final key in keysToDispose) {
      _textControllers.remove(key)?.dispose();
    }

    for (final entry in _textControllers.entries.toList()) {
      final key = entry.key;
      if (!usageCounts.containsKey(key)) {
        continue;
      }
      final controller = entry.value;
      final value = _sharedVariables[key];
      final text = value == null ? '' : value.toString();
      if (controller.text != text) {
        controller.value = controller.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange.empty,
        );
      }
    }
  }

  StandardDef? _findStandard(StandardAssignment assignment) {
    final trimmedId = assignment.standardId.trim();
    if (trimmedId.isNotEmpty) {
      for (final std in available) {
        if (std.id == trimmedId) {
          return std;
        }
      }
    }
    final codeMeta = (assignment.metadata['code'] as String?)?.trim();
    if (codeMeta != null && codeMeta.isNotEmpty) {
      for (final std in available) {
        if (std.code == codeMeta) {
          return std;
        }
      }
    }
    if (trimmedId.isNotEmpty) {
      for (final std in available) {
        if (std.code == trimmedId) {
          return std;
        }
      }
    }
    return null;
  }

  void _syncAssignment(StandardAssignment assignment, StandardDef std) {
    assignment.standardId = std.id;
    assignment.metadata['code'] = std.code;
    assignment.metadata['name'] = std.name;
    assignment.metadata.remove('legacy_unresolved');
    _pruneVariablesFor(assignment, std);
  }

  void _pruneVariablesFor(StandardAssignment assignment, StandardDef std) {
    if (assignment.variables.isEmpty) return;
    final allowed = std.parameters.map((p) => p.key).toSet();
    assignment.variables.removeWhere((key, _) => !allowed.contains(key));
  }

  bool _assignmentUsesKey(StandardAssignment assignment, String key) {
    final std = _findStandard(assignment);
    if (std != null) {
      for (final param in std.parameters) {
        if (param.key == key) {
          return true;
        }
      }
      return false;
    }
    return assignment.variables.containsKey(key);
  }

  void _setSharedValue(String key, dynamic value, {bool removeValue = false}) {
    setState(() {
      _sharedVariables[key] = removeValue ? null : value;

      for (final assignment in assignments) {
        if (_assignmentUsesKey(assignment, key)) {
          if (removeValue || value == null) {
            assignment.variables.remove(key);
          } else {
            assignment.variables[key] = value;
          }
        }
      }
    });

    if (!removeValue) {
      final controller = _textControllers[key];
      if (controller != null) {
        final text = value == null ? '' : value.toString();
        if (controller.text != text) {
          controller.value = controller.value.copyWith(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: TextRange.empty,
          );
        }
      }
    }
  }

  TextEditingController _ensureTextController(String key, String initialValue) {
    final existing = _textControllers[key];
    if (existing != null) {
      return existing;
    }
    final controller = TextEditingController(text: initialValue);
    _textControllers[key] = controller;
    return controller;
  }

  String _formatSharedValue(ParameterDef param) {
    final value = _sharedVariables[param.key];
    if (value == null) {
      return 'Not set';
    }
    if (value is bool) {
      return value ? 'Enabled' : 'Disabled';
    }
    if (value is num) {
      if (value is double && value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    if (value is String && value.isEmpty) {
      return 'Not set';
    }
    return value.toString();
  }

  Future<void> _addStandard() async {
    if (available.isEmpty) return;
    final std = await showDialog<StandardDef>(
      context: context,
      builder: (_) => _StandardSelectionDialog(choices: available),
    );
    if (std != null) {
      final assignment = StandardAssignment(
        standardId: std.id,
        metadata: {'code': std.code, 'name': std.name},
      );
      _syncAssignment(assignment, std);
      setState(() {
        assignments.add(assignment);
      });
      _refreshSharedParameters();
    }
  }

  void _duplicateAssignment(StandardAssignment assignment) {
    final index = assignments.indexOf(assignment);
    if (index < 0) return;
    final copy = assignment.copy(regenerateInstanceId: true);
    final std = _findStandard(copy);
    if (std != null) {
      _syncAssignment(copy, std);
    }
    setState(() {
      assignments.insert(index + 1, copy);
    });
    _refreshSharedParameters();
  }

  void _removeAssignment(StandardAssignment assignment) {
    setState(() {
      assignments.remove(assignment);
    });
    _refreshSharedParameters();
  }

  Future<void> _manageStandards() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StandardsManagerScreen()),
    );
    final repo = await createRepo();
    final list = await repo.listStandards();
    setState(() {
      available = list;
      _hydrateAssignments();
    });
    _refreshSharedParameters();
  }

  Widget _buildParamField(ParameterDef p) {
    final label = p.unit == null ? p.key : '${p.key} (${p.unit})';
    final currentValue = _sharedVariables[p.key];
    switch (p.type) {
      case ParamType.boolean:
        return SwitchListTile(
          key: ValueKey('${p.key}_bool_shared'),
          value: (currentValue as bool?) ?? false,
          title: Text(label),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          onChanged: (v) => _setSharedValue(p.key, v),
        );
      case ParamType.enumType:
        return DropdownButtonFormField<String>(
          key: ValueKey('${p.key}_enum_shared'),
          decoration: InputDecoration(labelText: label),
          value: currentValue is String && p.allowedValues.contains(currentValue)
              ? currentValue
              : null,
          items: p.allowedValues
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            if (v == null) {
              _setSharedValue(p.key, null, removeValue: true);
            } else {
              _setSharedValue(p.key, v);
            }
          },
        );
      case ParamType.number:
        {
          final controller = _ensureTextController(
            p.key,
            currentValue == null ? '' : currentValue.toString(),
          );
          return TextFormField(
            key: ValueKey('${p.key}_num_shared'),
            controller: controller,
            decoration: InputDecoration(labelText: label),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed == null) {
                _setSharedValue(p.key, null, removeValue: true);
              } else {
                _setSharedValue(p.key, parsed);
              }
            },
          );
        }
      case ParamType.text:
      default:
        {
          final controller = _ensureTextController(
            p.key,
            currentValue?.toString() ?? '',
          );
          return TextFormField(
            key: ValueKey('${p.key}_text_shared'),
            controller: controller,
            decoration: InputDecoration(labelText: label),
            onChanged: (v) => _setSharedValue(p.key, v),
          );
        }
    }
  }

  Widget _buildAssignmentCard(
    int index,
    StandardAssignment assignment,
    Set<String> renderedKeys,
  ) {
    final theme = Theme.of(context);
    final std = _findStandard(assignment);
    final codeLabel = std?.code ??
        (assignment.metadata['code'] as String?) ??
        assignment.standardId;
    final nameLabel = std?.name ??
        (assignment.metadata['name'] as String?) ??
        '';
    final params = std?.parameters ?? const <ParameterDef>[];
    final hasParams = params.isNotEmpty;
    return Container(
      key: ValueKey(assignment.instanceId),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. $codeLabel',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (nameLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        nameLabel,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                    if (std == null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'This standard is no longer available. Update your library to restore it.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.amberAccent),
                      ),
                    ] else if (!hasParams) ...[
                      const SizedBox(height: 6),
                      Text(
                        'No parameters required.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Duplicate standard',
                    icon: const Icon(Icons.copy_all_outlined),
                    onPressed: () => _duplicateAssignment(assignment),
                  ),
                  IconButton(
                    tooltip: 'Remove standard',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeAssignment(assignment),
                  ),
                ],
              ),
            ],
          ),
          if (hasParams) ...[
            const SizedBox(height: 12),
            for (final p in params)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: renderedKeys.add(p.key)
                    ? _buildParamField(p)
                    : Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.02),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Text(
                          '${p.key} reuses the shared value ${_formatSharedValue(p)} '
                          'across ${_parameterUsageCounts[p.key] ?? 1} standards.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final renderedKeys = <String>{};
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
                'assignments': assignments
                    .map((assignment) => assignment.copy())
                    .toList(),
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
                    'Standards & parameters',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (assignments.isEmpty)
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
                    for (var i = 0; i < assignments.length; i++)
                      _buildAssignmentCard(i, assignments[i], renderedKeys),
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
