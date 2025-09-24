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
  StandardsRepo? repo;
  List<ParameterDef> parameters = [];
  final List<String> _parameterIds = [];
  int _nextParameterId = 0;
  bool _loading = true;
  String _searchQuery = '';
  List<ParameterDef> _originalParameters = [];

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
    _initRepo();
  }

  Future<void> _initRepo() async {
    try {
      final loadedRepo = await createRepo();
      final list = await loadedRepo.loadGlobalParameters();
      if (!mounted) return;
      setState(() {
        repo = loadedRepo;
        parameters = list;
        _originalParameters = List<ParameterDef>.from(list);
        _resetParameterIds();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        repo = null;
        parameters = [];
        _originalParameters = [];
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
      final repo = this.repo;
      if (repo == null) return;
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
      final result = await repo.saveGlobalParameters(
        ParametersSaveRequest(
          original: _originalParameters,
          updated: cleaned,
        ),
      );

      if (result.hasConflicts) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Conflicts detected. Review the global parameters before saving.',
            ),
          ),
        );
        await _showConflictDialog(result);
        return;
      }

      setState(() {
        parameters = List<ParameterDef>.from(result.merged);
        _originalParameters = List<ParameterDef>.from(result.merged);
        _resetParameterIds();
      });
      if (!mounted) return;
      if (result.hasRemoteChanges) {
        _showMergeSnackBar(result.remoteChanges);
      } else if (result.wroteFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parameters saved.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to save.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e')),
      );
    }
  }

  Future<void> _showConflictDialog(ParametersSaveResult result) async {
    if (!mounted) return;
    final shouldReload = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Conflicts detected'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Another session updated these parameters. Resolve the conflicts below or reload the remote data.',
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
        _resetParameterIds();
      });
    }
  }

  void _showMergeSnackBar(Set<String> keys) {
    final items = keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final preview = items.length > 3
        ? '${items.take(3).join(', ')} and ${items.length - 3} more'
        : items.join(', ');
    final message = items.isEmpty
        ? 'Parameters saved.'
        : 'Merged updates for: $preview';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: items.isEmpty
            ? null
            : SnackBarAction(
                label: 'Review',
                onPressed: () => _showMergeDetails(items),
              ),
      ),
    );
  }

  void _showMergeDetails(List<String> keys) {
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
                for (final key in keys)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(key),
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
    final theme = Theme.of(context);
    final repo = this.repo;
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
              onPressed: repo == null ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save changes'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : repo == null
              ? const Center(child: Text('Failed to load repository.'))
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
                                      keySuggestions: parameters
                                          .map((p) => p.key.trim())
                                          .where((k) => k.isNotEmpty)
                                          .toSet()
                                          .toList(),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: repo == null ? null : _addParameter,
        icon: const Icon(Icons.add),
        label: const Text('Add parameter'),
      ),
    );
  }
}
