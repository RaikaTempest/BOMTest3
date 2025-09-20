import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';
import 'widgets/bom_scaffold.dart';
import 'widgets/glass_container.dart';
import 'widgets/parameter_editor.dart';

class GlobalParametersScreen extends StatefulWidget {
  const GlobalParametersScreen({super.key});

  @override
  State<GlobalParametersScreen> createState() => _GlobalParametersScreenState();
}

class _GlobalParametersScreenState extends State<GlobalParametersScreen> {
  late final StandardsRepo repo;
  List<ParameterDef> parameters = [];
  final List<String> _parameterIds = [];
  int _nextParameterId = 0;
  bool _loading = true;
  String _searchQuery = '';

  String _createParameterId() => 'global_param_${_nextParameterId++}';

  void _resetParameterIds() {
    _nextParameterId = 0;
    _parameterIds
      ..clear()
      ..addAll(List.generate(parameters.length, (_) => _createParameterId()));
  }

  @override
  void initState() {
    super.initState();
    repo = createRepo();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await repo.loadGlobalParameters();
      setState(() {
        parameters = list;
        _resetParameterIds();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        parameters = [];
        _resetParameterIds();
        _loading = false;
      });
    }
  }

  void _onParameterChanged(int index, ParameterDef def) {
    setState(() {
      parameters[index] = def;
    });
  }

  void _removeParameter(int index) {
    setState(() {
      parameters.removeAt(index);
      _parameterIds.removeAt(index);
    });
  }

  void _addParameter() {
    setState(() {
      parameters.add(ParameterDef(key: '', type: ParamType.text));
      _parameterIds.add(_createParameterId());
    });
  }

  Future<void> _save() async {
    try {
      final cleaned = <ParameterDef>[];
      final seen = <String>{};
      for (final p in parameters) {
        final key = p.key.trim();
        if (key.isEmpty) {
          continue;
        }
        if (!seen.add(key)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Duplicate parameter key: $key')),
          );
          return;
        }
        final unit = p.unit?.trim();
        cleaned.add(
          ParameterDef(
            key: key,
            type: p.type,
            unit: unit == null || unit.isEmpty ? null : unit,
            allowedValues: p.allowedValues
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
            required: p.required,
          ),
        );
      }
      cleaned.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
      await repo.saveGlobalParameters(cleaned);
      setState(() {
        parameters = List<ParameterDef>.from(cleaned);
        _resetParameterIds();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parameters saved.')),
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
    final theme = Theme.of(context);
    final query = _searchQuery.trim().toLowerCase();
    final filteredEntries = parameters
        .asMap()
        .entries
        .where(
          (entry) => query.isEmpty
              ? true
              : entry.value.key.toLowerCase().contains(query),
        )
        .toList();
    return BomScaffold(
      appBar: AppBar(
        title: const Text('Global Parameters'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save changes'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : parameters.isEmpty
              ? Center(
                  child: GlassContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune,
                            size: 46, color: theme.colorScheme.secondary),
                        const SizedBox(height: 16),
                        Text(
                          'No parameters defined yet',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your global parameters to reuse them across every project.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search parameters',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredEntries.isEmpty
                            ? const Center(
                                child:
                                    Text('No parameters match your search.'),
                              )
                            : ListView.builder(
                                itemCount: filteredEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = filteredEntries[index];
                                  return GlassContainer(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    child: ParameterEditor(
                                      key: ValueKey(
                                        _parameterIds[entry.key],
                                      ),
                                      def: entry.value,
                                      onChanged: (p) =>
                                          _onParameterChanged(entry.key, p),
                                      onDelete: () => _removeParameter(entry.key),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addParameter,
        icon: const Icon(Icons.add),
        label: const Text('Add parameter'),
      ),
    );
  }
}
