import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';
import 'dynamic_component_rules_screen.dart';
import 'dialogs.dart';
import 'widgets/dynamic_component_editor.dart';
import 'widgets/parameter_editor.dart';

class StandardsManagerScreen extends StatefulWidget {
  const StandardsManagerScreen({super.key});

  @override
  State<StandardsManagerScreen> createState() => _StandardsManagerScreenState();
}

class _StandardsManagerScreenState extends State<StandardsManagerScreen> {
  late final StandardsRepo repo;
  List<StandardDef> standards = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    repo = createRepo();
    // Load existing standards.
    repo.listStandards().then((list) {
      setState(() => standards = list);
    });
  }

  Future<void> _refresh() async {
    final list = await repo.listStandards();
    setState(() => standards = list);
  }

  Future<void> _openDetail([StandardDef? std]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _StandardDetailScreen(repo: repo, existing: std),
      ),
    );
    if (changed == true) {
      _refresh();
    }
  }

  Future<void> _deleteStandard(StandardDef std) async {
    final firstConfirm = await showConfirmationDialog(
      context,
      title: 'Delete standard?',
      message:
          'This will permanently remove ${std.code} — ${std.name}. This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!firstConfirm) return;

    final secondConfirm = await showTextConfirmationDialog(
      context,
      title: 'Confirm deletion',
      message:
          'Type the standard code to confirm. Deleting a standard cannot be undone.',
      hintText: std.code,
      expectedText: std.code,
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!secondConfirm) return;

    try {
      await repo.deleteStandard(std.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted standard ${std.code}.')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete standard',
                              onPressed: () => _deleteStandard(s),
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
        onPressed: () => _openDetail(),
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
  bool _dirty = false;

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
    for (final p in globalParameters) {
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
    for (final c in globalDynamicComponents) {
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

  void _markDirty() {
    if (!_dirty) {
      setState(() {
        _dirty = true;
      });
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_dirty) return true;
    return await showConfirmationDialog(
      context,
      title: 'Discard changes?',
      message:
          'You have unsaved changes for this standard. Leave without saving?',
      confirmLabel: 'Discard',
      isDestructive: true,
    );
  }

  Future<void> _loadGlobalParameters() async {
    try {
      final list = await widget.repo.loadGlobalParameters();
      if (!mounted) return;
      setState(() {
        globalParameters = list;
        _combineGlobalAndCurrent();
        _loadingGlobalParameters = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
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
        globalDynamicComponents = list;
        _combineGlobalDynamicComponents();
        _loadingGlobalDynamicComponents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
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
      _dirty = true;
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
      _dirty = true;
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
    setState(() {
      dynamicComponents.add(_cloneDynamicComponent(selected));
      _dynamicComponentIds.add(_createDynamicComponentId());
      _combineGlobalDynamicComponents();
      _dirty = true;
    });
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
    );
  }

  void _onParameterChanged(int index, ParameterDef def) {
    setState(() {
      parameters[index] = def;
      _combineGlobalAndCurrent();
      _dirty = true;
    });
  }

  Future<void> _removeParameterAt(int index) async {
    final confirm = await showConfirmationDialog(
      context,
      title: 'Remove parameter?',
      message: 'This parameter will be removed from the standard.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirm) return;

    setState(() {
      parameters.removeAt(index);
      _parameterIds.removeAt(index);
      _combineGlobalAndCurrent();
      _dirty = true;
    });
  }

  Future<void> _removeStaticComponent(int index) async {
    final confirm = await showConfirmationDialog(
      context,
      title: 'Remove static component?',
      message: 'This component will be removed from the standard.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirm) return;

    setState(() {
      staticComponents.removeAt(index);
      _dirty = true;
    });
  }

  Future<void> _removeDynamicComponent(int index) async {
    final confirm = await showConfirmationDialog(
      context,
      title: 'Remove dynamic component?',
      message: 'This component will be removed from the standard.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirm) return;

    setState(() {
      dynamicComponents.removeAt(index);
      _dynamicComponentIds.removeAt(index);
      _combineGlobalDynamicComponents();
      _dirty = true;
    });
  }

  Future<void> _openRulesManager(int index) async {
    try {
      final updated = await Navigator.of(context).push<DynamicComponentDef>(
        MaterialPageRoute(
          builder: (_) => DynamicComponentRulesScreen(
            component: dynamicComponents[index],
            parameters: parameters,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        if (updated != null) {
          dynamicComponents[index] = updated;
          _dirty = true;
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
    code.addListener(_markDirty);
    name.addListener(_markDirty);
    parameters = e?.parameters.toList() ?? [];
    _resetParameterIds();
    staticComponents = e?.staticComponents.toList() ?? [];
    dynamicComponents = e?.dynamicComponents.toList() ?? [];
    _resetDynamicComponentIds();
    _combineGlobalDynamicComponents();
    _loadGlobalParameters();
    _loadGlobalDynamicComponents();
  }

  @override
  void dispose() {
    code.removeListener(_markDirty);
    name.removeListener(_markDirty);
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
        cleanedDynamic.add(
          DynamicComponentDef(
            name: nameValue,
            selectionStrategy: c.selectionStrategy,
            rules: c.rules,
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
      final global = await widget.repo.loadGlobalParameters();
      final map = <String, ParameterDef>{};
      for (final p in global) {
        final key = p.key.trim();
        if (key.isEmpty) continue;
        map[key] = p;
      }
      for (final p in cleaned) {
        map[p.key] = p;
      }
      final updatedGlobal = map.values.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
      await widget.repo.saveGlobalParameters(updatedGlobal);

      final globalDynamic = await widget.repo.loadGlobalDynamicComponents();
      final dynamicMap = <String, DynamicComponentDef>{};
      for (final c in globalDynamic) {
        final nameValue = c.name.trim();
        if (nameValue.isEmpty) continue;
        dynamicMap[nameValue] = c;
      }
      for (final c in cleanedDynamic) {
        dynamicMap[c.name] = c;
      }
      final updatedGlobalDynamic = dynamicMap.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await widget.repo.saveGlobalDynamicComponents(updatedGlobalDynamic);

      await widget.repo.saveStandard(std);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(widget.existing == null ? 'Add Standard' : 'Edit Standard'),
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
                    onChanged:
                        (c) => setState(() {
                          staticComponents[e.key] = c;
                          _dirty = true;
                        }),
                    onDelete: () => _removeStaticComponent(e.key),
                  ),
                )
                .toList(),
            TextButton.icon(
              onPressed:
                  () => setState(() {
                    staticComponents.add(StaticComponent(mm: '', qty: 1));
                    _dirty = true;
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
                      );
                      _combineGlobalDynamicComponents();
                      _dirty = true;
                    }),
                    onEditRules: () => _openRulesManager(e.key),
                    onDelete: () => _removeDynamicComponent(e.key),
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
                    _dirty = true;
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
        floatingActionButton: FloatingActionButton(
          onPressed: _save,
          child: const Icon(Icons.save),
        ),
      ),
    );
  }
}

class _StaticEditor extends StatefulWidget {
  final StaticComponent comp;
  final ValueChanged<StaticComponent> onChanged;
  final VoidCallback onDelete;

  const _StaticEditor({
    required this.comp,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_StaticEditor> createState() => _StaticEditorState();
}

class _StaticEditorState extends State<_StaticEditor> {
  late TextEditingController mm;
  late TextEditingController qty;

  @override
  void initState() {
    super.initState();
    mm = TextEditingController(text: widget.comp.mm);
    qty = TextEditingController(text: widget.comp.qty.toString());
  }

  void _notify() {
    widget.onChanged(
      StaticComponent(
        mm: mm.text.trim(),
        qty: int.tryParse(qty.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: mm,
                decoration: const InputDecoration(labelText: 'MM'),
                onChanged: (_) => _notify(),
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
