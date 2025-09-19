import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';
import 'dynamic_component_rules_screen.dart';
import 'widgets/parameter_editor.dart';

class StandardsManagerScreen extends StatefulWidget {
  const StandardsManagerScreen({super.key});

  @override
  State<StandardsManagerScreen> createState() => _StandardsManagerScreenState();
}

class _StandardsManagerScreenState extends State<StandardsManagerScreen> {
  late final StandardsRepo repo;
  List<StandardDef> standards = [];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Standards')),
      body: ListView.builder(
        itemCount: standards.length,
        itemBuilder: (_, i) {
          final s = standards[i];
          return ListTile(
            title: Text('${s.code} — ${s.name}'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _openDetail(s),
            ),
          );
        },
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
  List<ParameterDef> globalParameters = [];
  bool _loadingGlobalParameters = true;

  String _createParameterId() => 'standard_param_${_nextParameterId++}';

  void _resetParameterIds() {
    _nextParameterId = 0;
    _parameterIds
      ..clear()
      ..addAll(List.generate(parameters.length, (_) => _createParameterId()));
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
    final selected = await showDialog<ParameterDef>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select parameter'),
          children: [
            for (final option in options)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, option),
                child: Text('${option.key} (${paramTypeToString(option.type)})'),
              ),
          ],
        );
      },
    );
    if (selected == null) return;
    setState(() {
      parameters.add(_cloneParameter(selected));
      _parameterIds.add(_createParameterId());
      _combineGlobalAndCurrent();
    });
  }

  ParameterDef _cloneParameter(ParameterDef source) => ParameterDef(
        key: source.key,
        type: source.type,
        unit: source.unit,
        allowedValues: List<String>.from(source.allowedValues),
        required: source.required,
      );

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
            parameters: parameters,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        if (updated != null) {
          dynamicComponents[index] = updated;
        }
        _combineGlobalAndCurrent();
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
    _loadGlobalParameters();
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

      final std = StandardDef(
        code: code.text.trim(),
        name: name.text.trim(),
        parameters: cleaned,
        staticComponents: staticComponents,
        dynamicComponents: dynamicComponents,
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
            ...dynamicComponents
                .asMap()
                .entries
                .map(
                  (e) => _DynamicEditor(
                    comp: e.value,
                    onNameChanged:
                        (name) => setState(() {
                          final old = dynamicComponents[e.key];
                          dynamicComponents[e.key] = DynamicComponentDef(
                            name: name,
                            selectionStrategy: old.selectionStrategy,
                            rules: old.rules,
                          );
                        }),
                    onEditRules: () => _openRulesManager(e.key),
                    onDelete:
                        () => setState(() {
                          dynamicComponents.removeAt(e.key);
                        }),
                  ),
                )
                .toList(),
            TextButton.icon(
              onPressed:
                  () => setState(() {
                    dynamicComponents.add(
                      DynamicComponentDef(name: '', rules: []),
                    );
                  }),
              icon: const Icon(Icons.add),
              label: const Text('Add Dynamic Component'),
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

class _DynamicEditor extends StatefulWidget {
  final DynamicComponentDef comp;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onEditRules;
  final VoidCallback onDelete;

  const _DynamicEditor({
    required this.comp,
    required this.onNameChanged,
    required this.onEditRules,
    required this.onDelete,
  });

  @override
  State<_DynamicEditor> createState() => _DynamicEditorState();
}

class _DynamicEditorState extends State<_DynamicEditor> {
  late TextEditingController name;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.comp.name);
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
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: widget.onNameChanged,
              ),
            ),
            TextButton(
              onPressed: widget.onEditRules,
              child: const Text('Edit Rules'),
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
    name.dispose();
    super.dispose();
  }
}
