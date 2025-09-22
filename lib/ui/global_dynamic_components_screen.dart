import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';
import 'dynamic_component_rules_screen.dart';
import 'widgets/dynamic_component_editor.dart';

class GlobalDynamicComponentsScreen extends StatefulWidget {
  const GlobalDynamicComponentsScreen({super.key});

  @override
  State<GlobalDynamicComponentsScreen> createState() =>
      _GlobalDynamicComponentsScreenState();
}

class _GlobalDynamicComponentsScreenState
    extends State<GlobalDynamicComponentsScreen> {
  StandardsRepo? repo;
  List<DynamicComponentDef> components = [];
  final List<String> _componentIds = [];
  int _nextComponentId = 0;
  bool _loading = true;
  List<ParameterDef> parameters = [];
  String _searchQuery = '';
  List<DynamicComponentDef> _originalComponents = [];
  List<ParameterDef> _originalParameters = [];

  String _createComponentId() => 'global_dynamic_${_nextComponentId++}';

  void _resetIds() {
    _nextComponentId = 0;
    _componentIds
      ..clear()
      ..addAll(
        List.generate(components.length, (_) => _createComponentId()),
      );
  }

  @override
  void initState() {
    super.initState();
    _initRepo();
  }

  Future<void> _initRepo() async {
    try {
      final loadedRepo = await createRepo();
      final loadedComponents = await loadedRepo.loadGlobalDynamicComponents();
      final loadedParameters = await loadedRepo.loadGlobalParameters();
      if (!mounted) return;
      setState(() {
        repo = loadedRepo;
        components = loadedComponents;
        parameters = loadedParameters;
        _originalComponents = List<DynamicComponentDef>.from(loadedComponents);
        _originalParameters = List<ParameterDef>.from(loadedParameters);
        _resetIds();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        repo = null;
        components = [];
        parameters = [];
        _originalComponents = [];
        _originalParameters = [];
        _resetIds();
        _loading = false;
      });
    }
  }

  void _normalizeParameters() {
    final map = <String, ParameterDef>{};
    for (final p in parameters) {
      final key = p.key.trim();
      if (key.isEmpty) continue;
      map[key] = p;
    }
    parameters = map.values.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
  }

  void _onNameChanged(int index, String value) {
    setState(() {
      final old = components[index];
      components[index] = DynamicComponentDef(
        name: value,
        selectionStrategy: old.selectionStrategy,
        rules: old.rules,
      );
    });
  }

  Future<void> _editRules(int index) async {
    try {
      final updated = await Navigator.of(context).push<DynamicComponentDef>(
        MaterialPageRoute(
          builder: (_) => DynamicComponentRulesScreen(
            component: components[index],
            parameters: parameters,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        if (updated != null) {
          components[index] = updated;
        }
        _normalizeParameters();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Edit error: $e')),
      );
    }
  }

  void _removeComponent(int index) {
    setState(() {
      components.removeAt(index);
      _componentIds.removeAt(index);
    });
  }

  void _addComponent() {
    setState(() {
      components.add(DynamicComponentDef(name: '', rules: []));
      _componentIds.add(_createComponentId());
    });
  }

  Future<void> _save() async {
    try {
      final repo = this.repo;
      if (repo == null) return;
      final cleaned = <DynamicComponentDef>[];
      final seenNames = <String>{};
      for (final c in components) {
        final name = c.name.trim();
        if (name.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dynamic component name cannot be empty.'),
            ),
          );
          return;
        }
        if (!seenNames.add(name)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Duplicate dynamic component name: $name')),
          );
          return;
        }
        cleaned.add(
          DynamicComponentDef(
            name: name,
            selectionStrategy: c.selectionStrategy,
            rules: c.rules,
          ),
        );
      }

      cleaned.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final componentResult = await repo.saveGlobalDynamicComponents(
        DynamicComponentsSaveRequest(
          original: _originalComponents,
          updated: cleaned,
        ),
      );

      if (componentResult.hasConflicts) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Conflicts detected. Review the dynamic components before saving.',
            ),
          ),
        );
        await _showComponentConflictDialog(componentResult);
        return;
      }

      final paramMap = <String, ParameterDef>{};
      for (final p in _originalParameters) {
        final key = p.key.trim();
        if (key.isEmpty) continue;
        paramMap[key] = p;
      }
      for (final p in parameters) {
        final key = p.key.trim();
        if (key.isEmpty) continue;
        paramMap[key] = p;
      }
      final updatedParams = paramMap.values.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

      final parameterResult = await repo.saveGlobalParameters(
        ParametersSaveRequest(
          original: _originalParameters,
          updated: updatedParams,
        ),
      );

      if (parameterResult.hasConflicts) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Parameter conflicts detected. Review the global parameters.',
            ),
          ),
        );
        await _showParameterConflictDialog(parameterResult);
        return;
      }

      if (!mounted) return;
      setState(() {
        components = List<DynamicComponentDef>.from(componentResult.merged);
        parameters = parameterResult.merged;
        _originalComponents = List<DynamicComponentDef>.from(componentResult.merged);
        _originalParameters = List<ParameterDef>.from(parameterResult.merged);
        _resetIds();
        _normalizeParameters();
      });

      if (componentResult.hasRemoteChanges) {
        _showComponentMergeSnackBar(componentResult.remoteChanges);
      } else if (componentResult.wroteFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dynamic components saved.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No component changes to save.')),
        );
      }

      if (parameterResult.hasRemoteChanges) {
        _showParameterMergeSnackBar(parameterResult.remoteChanges);
      } else if (parameterResult.wroteFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supporting parameters saved.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e')),
      );
    }
  }

  Future<void> _showComponentConflictDialog(
      DynamicComponentsSaveResult result) async {
    if (!mounted) return;
    final shouldReload = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dynamic component conflicts'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Another session updated these dynamic components. Resolve the conflicts below or reload the remote data.',
                ),
                const SizedBox(height: 12),
                for (final conflict in result.conflicts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(_describeComponentConflict(conflict)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reload remote data'),
            ),
          ],
        );
      },
    );

    if (shouldReload == true && mounted) {
      setState(() {
        components = List<DynamicComponentDef>.from(result.merged);
        _originalComponents = List<DynamicComponentDef>.from(result.merged);
        _resetIds();
      });
    }
  }

  Future<void> _showParameterConflictDialog(ParametersSaveResult result) async {
    if (!mounted) return;
    final shouldReload = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Parameter conflicts'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Another session updated the supporting parameters. Resolve the conflicts below or reload the remote data.',
                ),
                const SizedBox(height: 12),
                for (final conflict in result.conflicts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(_describeParameterConflict(conflict)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reload remote data'),
            ),
          ],
        );
      },
    );

    if (shouldReload == true && mounted) {
      setState(() {
        parameters = List<ParameterDef>.from(result.merged);
        _originalParameters = List<ParameterDef>.from(result.merged);
        _normalizeParameters();
      });
    }
  }

  void _showComponentMergeSnackBar(Set<String> names) {
    final list = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final preview = list.length > 3
        ? '${list.take(3).join(', ')} and ${list.length - 3} more'
        : list.join(', ');
    final message = list.isEmpty
        ? 'Dynamic components saved.'
        : 'Merged component updates for: $preview';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: list.isEmpty
            ? null
            : SnackBarAction(
                label: 'Review',
                onPressed: () => _showMergeDetails(list),
              ),
      ),
    );
  }

  void _showParameterMergeSnackBar(Set<String> keys) {
    final list = keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (list.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Merged parameter updates for: ${list.join(', ')}'),
      ),
    );
  }

  void _showMergeDetails(List<String> items) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Merged updates'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(item),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _describeComponentConflict(DynamicComponentConflict conflict) {
    switch (conflict.type) {
      case DynamicComponentConflictType.addition:
        return 'Component "${conflict.name}" was added elsewhere.';
      case DynamicComponentConflictType.removal:
        return 'Component "${conflict.name}" was removed remotely.';
      case DynamicComponentConflictType.field:
        final fields = conflict.fields.toList()..sort();
        final label = fields.join(', ');
        return 'Component "${conflict.name}" changed remotely: $label.';
    }
  }

  String _describeParameterConflict(ParameterConflict conflict) {
    switch (conflict.type) {
      case ParameterConflictType.addition:
        return 'Parameter "${conflict.key}" was added elsewhere.';
      case ParameterConflictType.removal:
        return 'Parameter "${conflict.key}" was removed remotely.';
      case ParameterConflictType.field:
        final fields = conflict.fields.toList()..sort();
        final label = fields.join(', ');
        return 'Parameter "${conflict.key}" changed remotely: $label.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = this.repo;
    final query = _searchQuery.trim().toLowerCase();
    final filteredEntries = components
        .asMap()
        .entries
        .where(
          (entry) => query.isEmpty
              ? true
              : entry.value.name.toLowerCase().contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Dynamic Components'),
        actions: [
          TextButton(
            onPressed: repo == null ? null : _save,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : repo == null
              ? const Center(child: Text('Failed to load repository.'))
              : components.isEmpty
                  ? const Center(
                      child: Text('No dynamic components defined yet.'),
                    )
                  : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search dynamic components',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filteredEntries.isEmpty
                            ? const Center(
                                child: Text(
                                    'No dynamic components match your search.'),
                              )
                            : ListView.builder(
                                itemCount: filteredEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = filteredEntries[index];
                                  return DynamicComponentEditor(
                                    key: ValueKey(
                                      _componentIds[entry.key],
                                    ),
                                    comp: entry.value,
                                    onNameChanged: (value) => _onNameChanged(
                                      entry.key,
                                      value,
                                    ),
                                    onEditRules: () => _editRules(entry.key),
                                    onDelete: () => _removeComponent(entry.key),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: repo == null ? null : _addComponent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
