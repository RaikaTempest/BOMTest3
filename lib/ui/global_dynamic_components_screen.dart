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
  late final StandardsRepo repo;
  List<DynamicComponentDef> components = [];
  final List<String> _componentIds = [];
  int _nextComponentId = 0;
  bool _loading = true;
  List<ParameterDef> parameters = [];
  String _searchQuery = '';

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
    repo = createRepo();
    _load();
  }

  Future<void> _load() async {
    try {
      final loadedComponents = await repo.loadGlobalDynamicComponents();
      final loadedParameters = await repo.loadGlobalParameters();
      if (!mounted) return;
      setState(() {
        components = loadedComponents;
        parameters = loadedParameters;
        _resetIds();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        components = [];
        parameters = [];
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
      await repo.saveGlobalDynamicComponents(cleaned);

      final existingParams = await repo.loadGlobalParameters();
      final paramMap = <String, ParameterDef>{};
      for (final p in existingParams) {
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
      await repo.saveGlobalParameters(updatedParams);

      if (!mounted) return;
      setState(() {
        components = List<DynamicComponentDef>.from(cleaned);
        parameters = updatedParams;
        _resetIds();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dynamic components saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _save,
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
        onPressed: _addComponent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
