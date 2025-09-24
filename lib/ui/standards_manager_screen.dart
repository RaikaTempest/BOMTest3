import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';
import 'dynamic_component_rules_screen.dart';
import 'widgets/dynamic_component_editor.dart';
import 'widgets/parameter_editor.dart';

class StandardsManagerScreen extends StatefulWidget {
  const StandardsManagerScreen({super.key});

  @override
  State<StandardsManagerScreen> createState() => _StandardsManagerScreenState();
}

class _StandardsManagerScreenState extends State<StandardsManagerScreen> {
  StandardsRepo? repo;
  List<StandardDef> standards = [];
  String _searchQuery = '';
  bool _loadingRepo = true;

  @override
  void initState() {
    super.initState();
    _initRepo();
  }

  Future<void> _initRepo() async {
    try {
      final loadedRepo = await createRepo();
      final list = await loadedRepo.listStandards();
      if (!mounted) return;
      setState(() {
        repo = loadedRepo;
        standards = list;
        _loadingRepo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        repo = null;
        standards = [];
        _loadingRepo = false;
      });
    }
  }

  Future<void> _refresh() async {
    final repo = this.repo;
    if (repo == null) return;
    final list = await repo.listStandards();
    if (!mounted) return;
    setState(() => standards = list);
  }

  Future<void> _openDetail([StandardDef? std]) async {
    final repo = this.repo;
    if (repo == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _StandardDetailScreen(repo: repo, existing: std),
      ),
    );
    if (changed == true) {
      _refresh();
    }
  }

  Future<void> _confirmDelete(StandardDef std) async {
    final repo = this.repo;
    if (repo == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete standard'),
        content: Text(
          'Are you sure you want to delete "${std.code} — ${std.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await repo.deleteStandard(std.code);
      if (!mounted) return;
      setState(() {
        standards.removeWhere((s) => s.code == std.code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = this.repo;
    if (_loadingRepo) {
      return Scaffold(
        appBar: AppBar(title: const Text('Standards')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Standards')),
        body: const Center(child: Text('Failed to load repository.')),
      );
    }
    final query = _searchQuery.trim().toLowerCase();
    final filteredStandards = query.isEmpty
        ? standards
        : standards
            .where(
              (s) =>
                  s.code.toLowerCase().contains(query) ||
                  s.name.toLowerCase().contains(query),
            )
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Standards')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search standards',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: filteredStandards.isEmpty
                ? const Center(child: Text('No standards found.'))
                : ListView.builder(
                    itemCount: filteredStandards.length,
                  itemBuilder: (_, i) {
                    final s = filteredStandards[i];
                    return ListTile(
                      title: Text('${s.code} — ${s.name}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit standard',
                            onPressed: () => _openDetail(s),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Delete standard',
                            onPressed: () => _confirmDelete(s),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openDetail,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StandardDetailScreen extends StatefulWidget {
  final StandardsRepo repo;
  final StandardDef? existing;
  const _StandardDetailScreen({required this.repo, this.existing});

  @override
  State<_StandardDetailScreen> createState() => _StandardDetailScreenState();
}

class _StandardDetailScreenState extends State<_StandardDetailScreen> {
  late final TextEditingController code;
  late final TextEditingController name;
  List<ParameterDef> parameters = [];
  final List<String> _parameterIds = [];
  int _nextParameterId = 0;
  List<StaticComponent> staticComponents = [];
  List<DynamicComponentDef> dynamicComponents = [];
  final List<String> _dynamicComponentIds = [];
  int _nextDynamicComponentId = 0;
  List<ParameterDef> globalParameters = [];
  bool _loadingGlobalParameters = true;
  List<DynamicComponentDef> globalDynamicComponents = [];
  bool _loadingGlobalDynamicComponents = true;
  StandardDef? _originalStandard;
  List<ParameterDef> _originalGlobalParameters = [];
  List<ParameterDef> _serverGlobalParameters = [];
  List<DynamicComponentDef> _originalGlobalDynamicComponents = [];
  List<DynamicComponentDef> _serverGlobalDynamicComponents = [];

  String _createParameterId() => 'standard_param_${_nextParameterId++}';

  void _resetParameterIds() {
    _nextParameterId = 0;
    _parameterIds
      ..clear()
      ..addAll(List.generate(parameters.length, (_) => _createParameterId()));
  }

  String _createDynamicComponentId() =>
      'standard_dynamic_${_nextDynamicComponentId++}';

  void _resetDynamicComponentIds() {
    _nextDynamicComponentId = 0;
    _dynamicComponentIds
      ..clear()
      ..addAll(
        List.generate(dynamicComponents.length, (_) => _createDynamicComponentId()),
      );
  }

  void _combineGlobalAndCurrent() {
    final map = <String, ParameterDef>{};
    for (final p in _serverGlobalParameters) {
      final key = p.key.trim();
      if (key.isEmpty) continue;
      map[key] = p;
    }
    for (final p in parameters) {
      final key = p.key.trim();
      if (key.isEmpty) continue;
      map[key] = p;
    }
    globalParameters = map.values.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
  }

  void _combineGlobalDynamicComponents() {
    final map = <String, DynamicComponentDef>{};
    for (final c in _serverGlobalDynamicComponents) {
      final name = c.name.trim();
      if (name.isEmpty) continue;
      map[name] = c;
    }
    for (final c in dynamicComponents) {
      final name = c.name.trim();
      if (name.isEmpty) continue;
      map[name] = c;
    }
    globalDynamicComponents = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _loadGlobalParameters() async {
    try {
      final list = await widget.repo.loadGlobalParameters();
      if (!mounted) return;
      setState(() {
        _serverGlobalParameters = List<ParameterDef>.from(list);
        _originalGlobalParameters = List<ParameterDef>.from(list);
        globalParameters = List<ParameterDef>.from(_serverGlobalParameters);
        _combineGlobalAndCurrent();
        _loadingGlobalParameters = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverGlobalParameters = [];
        _originalGlobalParameters = [];
        globalParameters = [];
        _combineGlobalAndCurrent();
        _loadingGlobalParameters = false;
      });
    }
  }

  Future<void> _loadGlobalDynamicComponents() async {
    try {
      final list = await widget.repo.loadGlobalDynamicComponents();
      if (!mounted) return;
      setState(() {
        _serverGlobalDynamicComponents =
            List<DynamicComponentDef>.from(list);
        _originalGlobalDynamicComponents =
            List<DynamicComponentDef>.from(list);
        globalDynamicComponents =
            List<DynamicComponentDef>.from(_serverGlobalDynamicComponents);
        _combineGlobalDynamicComponents();
        _loadingGlobalDynamicComponents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverGlobalDynamicComponents = [];
        _originalGlobalDynamicComponents = [];
        globalDynamicComponents = [];
        _combineGlobalDynamicComponents();
        _loadingGlobalDynamicComponents = false;
      });
    }
  }

  void _addNewParameter() {
    setState(() {
      parameters.add(ParameterDef(key: '', type: ParamType.text));
      _parameterIds.add(_createParameterId());
      _combineGlobalAndCurrent();
    });
  }

  Future<void> _addExistingParameter() async {
    if (_loadingGlobalParameters) return;
    final existingKeys = parameters.map((e) => e.key).toSet();
    final options = globalParameters
        .where((p) => p.key.isNotEmpty && !existingKeys.contains(p.key))
        .toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available global parameters to add.')),
      );
      return;
    }
    final selected = await _showParameterSelectionDialog(options);
    if (selected == null) return;
    setState(() {
      parameters.add(_cloneParameter(selected));
      _parameterIds.add(_createParameterId());
      _combineGlobalAndCurrent();
    });
  }

  Future<void> _addExistingDynamicComponent() async {
    if (_loadingGlobalDynamicComponents) return;
    final existingNames = dynamicComponents.map((e) => e.name).toSet();
    final options = globalDynamicComponents
        .where((c) => c.name.isNotEmpty && !existingNames.contains(c.name))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available global dynamic components to add.'),
        ),
      );
      return;
    }
    final selected = await _showDynamicComponentSelectionDialog(options);
    if (selected == null) return;
    final referencedParams = _collectReferencedParameterKeys(selected);
    final normalizedExisting = parameters.map((e) => e.key.trim()).toSet();
    final paramsToAdd = <ParameterDef>[];
    for (final key in referencedParams) {
      if (key.isEmpty || normalizedExisting.contains(key)) continue;
      final globalParam = _findGlobalParameter(key);
      if (globalParam != null) {
        paramsToAdd.add(_cloneParameter(globalParam));
        normalizedExisting.add(key);
      }
    }
    setState(() {
      for (final param in paramsToAdd) {
        parameters.add(param);
        _parameterIds.add(_createParameterId());
      }
      dynamicComponents.add(_cloneDynamicComponent(selected));
      _dynamicComponentIds.add(_createDynamicComponentId());
      if (paramsToAdd.isNotEmpty) {
        _combineGlobalAndCurrent();
      }
      _combineGlobalDynamicComponents();
    });
  }

  Set<String> _collectReferencedParameterKeys(
    DynamicComponentDef component,
  ) {
    final keys = <String>{};

    void visit(dynamic node) {
      if (node is Map) {
        final dynamic varValue = node['var'];
        if (varValue is String) {
          final trimmed = varValue.trim();
          if (trimmed.isNotEmpty) {
            keys.add(trimmed);
          }
        }
        for (final value in node.values) {
          visit(value);
        }
      } else if (node is List) {
        for (final value in node) {
          visit(value);
        }
      }
    }

    for (final rule in component.rules) {
      visit(rule.expr);
    }

    return keys;
  }

  ParameterDef? _findGlobalParameter(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;

    for (final param in _serverGlobalParameters) {
      if (param.key.trim() == trimmed) {
        return param;
      }
    }
    for (final param in globalParameters) {
      if (param.key.trim() == trimmed) {
        return param;
      }
    }
    return null;
  }

  Future<ParameterDef?> _showParameterSelectionDialog(
    List<ParameterDef> options,
  ) async {
    return showDialog<ParameterDef>(
      context: context,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = options
                .where((option) {
                  if (query.isEmpty) return true;
                  final lower = query.toLowerCase();
                  return option.key.toLowerCase().contains(lower) ||
                      (option.unit?.toLowerCase().contains(lower) ?? false);
                })
                .toList();
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select parameter'),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search parameters',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        query = value.trim();
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 400,
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No parameters match your search.'),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          return ListTile(
                            title: Text(
                                '${option.key} (${paramTypeToString(option.type)})'),
                            subtitle: option.unit == null ||
                                    option.unit!.trim().isEmpty
                                ? null
                                : Text(option.unit!),
                            onTap: () => Navigator.pop(context, option),
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Future<DynamicComponentDef?> _showDynamicComponentSelectionDialog(
    List<DynamicComponentDef> options,
  ) async {
    return showDialog<DynamicComponentDef>(
      context: context,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = options
                .where(
                  (option) => query.isEmpty
                      ? true
                      : option.name.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select dynamic component'),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search components',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        query = value.trim();
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 400,
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No dynamic components match your search.'),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          return ListTile(
                            title: Text(option.name),
                            onTap: () => Navigator.pop(context, option),
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }

  ParameterDef _cloneParameter(ParameterDef source) => ParameterDef(
        key: source.key,
        type: source.type,
        unit: source.unit,
        allowedValues: List<String>.from(source.allowedValues),
        required: source.required,
      );

  DynamicComponentDef _cloneDynamicComponent(DynamicComponentDef source) {
    return DynamicComponentDef(
      name: source.name,
      selectionStrategy: source.selectionStrategy,
      rules: source.rules
          .map(
            (rule) => RuleDef(
              expr:
                  jsonDecode(jsonEncode(rule.expr)) as Map<String, dynamic>,
              outputs: rule.outputs
                  .map(
                    (o) => OutputSpec(
                      mm: o.mm,
                      qty: o.qty,
                      qtyFormula: o.qtyFormula,
                    ),
                  )
                  .toList(),
              priority: rule.priority,
            ),
          )
          .toList(),
      matrix: source.matrix == null
          ? null
          : ConnectorMatrix.fromJson(
              (jsonDecode(jsonEncode(source.matrix!.toJson())) as Map)
                  .cast<String, dynamic>(),
            ),
      mmPattern: source.mmPattern,
    );
  }

  void _onParameterChanged(int index, ParameterDef def) {
    setState(() {
      parameters[index] = def;
      _combineGlobalAndCurrent();
    });
  }

  void _removeParameterAt(int index) {
    setState(() {
      parameters.removeAt(index);
      _parameterIds.removeAt(index);
      _combineGlobalAndCurrent();
    });
  }

  Future<void> _openRulesManager(int index) async {
    try {
      final updated = await Navigator.of(context).push<DynamicComponentDef>(
        MaterialPageRoute(
          builder: (_) => DynamicComponentRulesScreen(
            component: dynamicComponents[index],
            parameters: globalParameters,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        if (updated != null) {
          dynamicComponents[index] = updated;
        }
        _combineGlobalAndCurrent();
        _combineGlobalDynamicComponents();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Edit error: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    code = TextEditingController(text: e?.code ?? '');
    name = TextEditingController(text: e?.name ?? '');
    parameters = e?.parameters.toList() ?? [];
    _resetParameterIds();
    staticComponents = e?.staticComponents.toList() ?? [];
    dynamicComponents = e?.dynamicComponents.toList() ?? [];
    _resetDynamicComponentIds();
    _originalStandard = e;
    _combineGlobalDynamicComponents();
    _loadGlobalParameters();
    _loadGlobalDynamicComponents();
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final cleaned = <ParameterDef>[];
      final seenKeys = <String>{};
      for (final p in parameters) {
        final key = p.key.trim();
        if (key.isEmpty) {
          continue;
        }
        if (!seenKeys.add(key)) {
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

      final cleanedDynamic = <DynamicComponentDef>[];
      final seenDynamicNames = <String>{};
      for (final c in dynamicComponents) {
        final nameValue = c.name.trim();
        if (nameValue.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dynamic component name cannot be empty.'),
            ),
          );
          return;
        }
        if (!seenDynamicNames.add(nameValue)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Duplicate dynamic component name: $nameValue')),
          );
          return;
        }
        final trimmedPattern = c.mmPattern?.trim();
        cleanedDynamic.add(
          DynamicComponentDef(
            name: nameValue,
            selectionStrategy: c.selectionStrategy,
            rules: c.rules,
            matrix: c.matrix,
            mmPattern: trimmedPattern == null || trimmedPattern.isEmpty
                ? null
                : trimmedPattern,
          ),
        );
      }

      final std = StandardDef(
        code: code.text.trim(),
        name: name.text.trim(),
        parameters: cleaned,
        staticComponents: staticComponents,
        dynamicComponents: cleanedDynamic,
      );

      final paramMap = <String, ParameterDef>{};
      for (final p in _serverGlobalParameters) {
        final key = p.key.trim();
        if (key.isEmpty) continue;
        paramMap[key] = p;
      }
      for (final p in cleaned) {
        paramMap[p.key] = p;
      }
      final updatedGlobal = paramMap.values.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

      final paramResult = await widget.repo.saveGlobalParameters(
        ParametersSaveRequest(
          original: _originalGlobalParameters,
          updated: updatedGlobal,
        ),
      );

      if (paramResult.hasConflicts) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Global parameter conflicts detected. Resolve them before saving.',
            ),
          ),
        );
        await _showParameterConflictDialog(paramResult);
        return;
      }

      final dynamicMap = <String, DynamicComponentDef>{};
      for (final c in _serverGlobalDynamicComponents) {
        final nameValue = c.name.trim();
        if (nameValue.isEmpty) continue;
        dynamicMap[nameValue] = c;
      }
      for (final c in cleanedDynamic) {
        dynamicMap[c.name] = c;
      }
      final updatedGlobalDynamic = dynamicMap.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final dynamicResult = await widget.repo.saveGlobalDynamicComponents(
        DynamicComponentsSaveRequest(
          original: _originalGlobalDynamicComponents,
          updated: updatedGlobalDynamic,
        ),
      );

      if (dynamicResult.hasConflicts) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dynamic component conflicts detected. Resolve them before saving.',
            ),
          ),
        );
        await _showDynamicConflictDialog(dynamicResult);
        return;
      }

      final standardResult = await widget.repo.saveStandard(
        StandardSaveRequest(
          original: _originalStandard,
          updated: std,
        ),
      );

      if (standardResult.hasConflicts) {
        if (!mounted) return;
        await _showStandardConflictDialog(standardResult);
        return;
      }

      setState(() {
        parameters = cleaned;
        dynamicComponents = cleanedDynamic;
        _serverGlobalParameters = List<ParameterDef>.from(paramResult.merged);
        _originalGlobalParameters =
            List<ParameterDef>.from(paramResult.merged);
        _serverGlobalDynamicComponents =
            List<DynamicComponentDef>.from(dynamicResult.merged);
        _originalGlobalDynamicComponents =
            List<DynamicComponentDef>.from(dynamicResult.merged);
        _originalStandard = standardResult.merged;
        _resetParameterIds();
        _resetDynamicComponentIds();
        globalParameters = List<ParameterDef>.from(_serverGlobalParameters);
        _combineGlobalAndCurrent();
        globalDynamicComponents =
            List<DynamicComponentDef>.from(_serverGlobalDynamicComponents);
        _combineGlobalDynamicComponents();
      });

      if (!mounted) return;

      if (paramResult.hasRemoteChanges) {
        _showParameterMergeSnackBar(paramResult.remoteChanges);
      }
      if (dynamicResult.hasRemoteChanges) {
        _showDynamicMergeSnackBar(dynamicResult.remoteChanges);
      }

      if (standardResult.wroteFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Standard saved.')),
        );
      } else if (!standardResult.alreadyUpToDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to save.')),
        );
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save error: $e')));
    }
  }

  Future<void> _showParameterConflictDialog(
      ParametersSaveResult result) async {
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
                  'Another session updated the global parameters. Resolve the conflicts below or reload the remote data.',
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
        _serverGlobalParameters = List<ParameterDef>.from(result.merged);
        _originalGlobalParameters = List<ParameterDef>.from(result.merged);
        globalParameters = List<ParameterDef>.from(_serverGlobalParameters);
        _combineGlobalAndCurrent();
      });
    }
  }

  Future<void> _showDynamicConflictDialog(
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
                  'Another session updated the global dynamic components. Resolve the conflicts below or reload the remote data.',
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
        _serverGlobalDynamicComponents =
            List<DynamicComponentDef>.from(result.merged);
        _originalGlobalDynamicComponents =
            List<DynamicComponentDef>.from(result.merged);
        globalDynamicComponents =
            List<DynamicComponentDef>.from(_serverGlobalDynamicComponents);
        _combineGlobalDynamicComponents();
      });
    }
  }

  Future<void> _showStandardConflictDialog(StandardSaveResult result) async {
    if (!mounted) return;
    final conflict = result.conflict;
    final message = conflict == null
        ? 'Another session updated this standard.'
        : switch (conflict.type) {
            StandardSaveConflictType.alreadyExists =>
                'A standard with code "${conflict.code}" already exists with different data.',
            StandardSaveConflictType.updatedRemotely =>
                'This standard was updated in another session. Reload the latest version to continue.',
            StandardSaveConflictType.deletedRemotely =>
                'This standard was deleted remotely.',
          };

    final reload = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Standard conflict'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reload standard'),
            ),
          ],
        );
      },
    );

    if (reload == true) {
      final remote = result.merged;
      if (remote != null && mounted) {
        setState(() {
          _originalStandard = remote;
          code.text = remote.code;
          name.text = remote.name;
          parameters = remote.parameters.toList();
          staticComponents = remote.staticComponents.toList();
          dynamicComponents = remote.dynamicComponents.toList();
          _resetParameterIds();
          _resetDynamicComponentIds();
        });
      }
    }
  }

  void _showParameterMergeSnackBar(Set<String> keys) {
    if (keys.isEmpty) return;
    final list = keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Merged parameter updates for: ${list.join(', ')}'),
      ),
    );
  }

  void _showDynamicMergeSnackBar(Set<String> names) {
    final list = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final preview = list.length > 3
        ? '${list.take(3).join(', ')} and ${list.length - 3} more'
        : list.join(', ');
    final message = list.isEmpty
        ? 'Dynamic components saved.'
        : 'Merged component updates for: $preview';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Standard' : 'Edit Standard'),
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
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            const Text('Parameters'),
            const SizedBox(height: 4),
            if (_loadingGlobalParameters)
              const LinearProgressIndicator(),
            if (_loadingGlobalParameters)
              const SizedBox(height: 8),
            ...parameters
                .asMap()
                .entries
                .map(
                  (e) => ParameterEditor(
                    key: ValueKey(_parameterIds[e.key]),
                    def: e.value,
                    onChanged: (p) => _onParameterChanged(e.key, p),
                    onDelete: () => _removeParameterAt(e.key),
                    keySuggestions: () {
                      final suggestions = <String>{
                        ...globalParameters
                            .map((p) => p.key.trim())
                            .where((k) => k.isNotEmpty),
                        ...parameters
                            .map((p) => p.key.trim())
                            .where((k) => k.isNotEmpty),
                      };
                      return suggestions.toList();
                    }(),
                  ),
                )
                .toList(),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _addNewParameter,
                  icon: const Icon(Icons.add),
                  label: const Text('New Parameter'),
                ),
                TextButton.icon(
                  onPressed:
                      _loadingGlobalParameters ? null : _addExistingParameter,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Add Existing Parameter'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Static Components'),
            const SizedBox(height: 4),
            ...staticComponents
                .asMap()
                .entries
                .map(
                  (e) => _StaticEditor(
                    comp: e.value,
                    availableDynamicComponents: globalDynamicComponents,
                    onChanged:
                        (c) => setState(() {
                          staticComponents[e.key] = c;
                        }),
                    onDelete:
                        () => setState(() {
                          staticComponents.removeAt(e.key);
                        }),
                  ),
                )
                .toList(),
            TextButton.icon(
              onPressed:
                  () => setState(() {
                    staticComponents.add(StaticComponent(mm: '', qty: 1));
                  }),
              icon: const Icon(Icons.add),
              label: const Text('Add Static Component'),
            ),
            const SizedBox(height: 8),
            const Text('Dynamic Components'),
            const SizedBox(height: 4),
            if (_loadingGlobalDynamicComponents)
              const LinearProgressIndicator(),
            if (_loadingGlobalDynamicComponents)
              const SizedBox(height: 8),
            ...dynamicComponents
                .asMap()
                .entries
                .map(
                  (e) => DynamicComponentEditor(
                    key: ValueKey(_dynamicComponentIds[e.key]),
                    comp: e.value,
                    onNameChanged: (name) => setState(() {
                      final old = dynamicComponents[e.key];
                      dynamicComponents[e.key] = DynamicComponentDef(
                        name: name,
                        selectionStrategy: old.selectionStrategy,
                        rules: old.rules,
                        matrix: old.matrix,
                        mmPattern: old.mmPattern,
                      );
                      _combineGlobalDynamicComponents();
                    }),
                    onEditRules: () => _openRulesManager(e.key),
                    onDelete:
                        () => setState(() {
                          dynamicComponents.removeAt(e.key);
                          _dynamicComponentIds.removeAt(e.key);
                          _combineGlobalDynamicComponents();
                        }),
                  ),
                )
                .toList(),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() {
                    dynamicComponents.add(
                      DynamicComponentDef(name: '', rules: []),
                    );
                    _dynamicComponentIds.add(_createDynamicComponentId());
                    _combineGlobalDynamicComponents();
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('New Dynamic Component'),
                ),
                TextButton.icon(
                  onPressed: _loadingGlobalDynamicComponents
                      ? null
                      : _addExistingDynamicComponent,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Add Existing Dynamic Component'),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _save,
        child: const Icon(Icons.save),
      ),
    );
  }
}

class _StaticEditor extends StatefulWidget {
  final StaticComponent comp;
  final ValueChanged<StaticComponent> onChanged;
  final VoidCallback onDelete;
  final List<DynamicComponentDef> availableDynamicComponents;

  const _StaticEditor({
    required this.comp,
    required this.onChanged,
    required this.onDelete,
    this.availableDynamicComponents = const [],
  });

  @override
  State<_StaticEditor> createState() => _StaticEditorState();
}

class _StaticEditorState extends State<_StaticEditor> {
  static const String _literalOption = '__literal__';
  late TextEditingController mm;
  late TextEditingController qty;
  late String _mmSource;

  TextSelection _clampSelection(TextSelection selection, int maxLength) {
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: maxLength);
    }

    int clampOffset(int offset) {
      if (offset < 0) return 0;
      if (offset > maxLength) return maxLength;
      return offset;
    }

    return TextSelection(
      baseOffset: clampOffset(selection.baseOffset),
      extentOffset: clampOffset(selection.extentOffset),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  void _syncController(TextEditingController controller, String text) {
    if (controller.text == text) return;
    final value = controller.value;
    controller.value = value.copyWith(
      text: text,
      selection: _clampSelection(value.selection, text.length),
      composing: TextRange.empty,
    );
  }

  @override
  void initState() {
    super.initState();
    mm = TextEditingController(text: widget.comp.mm ?? '');
    qty = TextEditingController(text: widget.comp.qty.toString());
    final dynamicName = widget.comp.dynamicMmComponent?.trim();
    _mmSource =
        (dynamicName != null && dynamicName.isNotEmpty) ? dynamicName : _literalOption;
  }

  @override
  void didUpdateWidget(covariant _StaticEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comp.mm != widget.comp.mm) {
      _syncController(mm, widget.comp.mm ?? '');
    }
    if (oldWidget.comp.qty != widget.comp.qty) {
      _syncController(qty, widget.comp.qty.toString());
    }
    final dynamicName = widget.comp.dynamicMmComponent?.trim();
    final nextSource =
        (dynamicName != null && dynamicName.isNotEmpty) ? dynamicName : _literalOption;
    if (nextSource != _mmSource) {
      _mmSource = nextSource;
    }
  }

  void _notify() {
    final literal = mm.text.trim();
    widget.onChanged(
      StaticComponent(
        mm: literal.isEmpty ? null : literal,
        dynamicMmComponent:
            _mmSource == _literalOption ? null : _mmSource,
        qty: int.tryParse(qty.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynamicNames = widget.availableDynamicComponents
        .map((e) => e.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final dropdownItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: _literalOption,
        child: Text('Literal MM'),
      ),
      ...dynamicNames.map(
        (name) => DropdownMenuItem<String>(
          value: name,
          child: Text('Dynamic: $name'),
        ),
      ),
    ];
    if (_mmSource != _literalOption && !dynamicNames.contains(_mmSource)) {
      dropdownItems.add(
        DropdownMenuItem<String>(
          value: _mmSource,
          child: Text('Dynamic: $_mmSource'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _mmSource,
                    decoration: const InputDecoration(labelText: 'MM Source'),
                    items: dropdownItems,
                    isExpanded: true,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _mmSource = value;
                      });
                      _notify();
                    },
                  ),
                  if (_mmSource == _literalOption) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: mm,
                      decoration: const InputDecoration(labelText: 'MM'),
                      onChanged: (_) => _notify(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: qty,
                decoration: const InputDecoration(labelText: 'Qty'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _notify(),
              ),
            ),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    mm.dispose();
    qty.dispose();
    super.dispose();
  }
}
