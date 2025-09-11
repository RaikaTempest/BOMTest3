import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';
import 'rule_wizard.dart';

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
  List<StaticComponent> staticComponents = [];
  List<DynamicComponentDef> dynamicComponents = [];

  Future<void> _openRuleWizard(int index) async {
    try {
      final updated = await Navigator.of(context).push<DynamicComponentDef>(
        MaterialPageRoute(
          builder:
              (_) => RuleWizard(
                parent: dynamicComponents[index],
                parameters: parameters,
              ),
        ),
      );
      setState(() {
        if (updated != null) {
          dynamicComponents[index] = updated;
        }
        // ensure UI reflects any parameter changes made inside the wizard
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
    staticComponents = e?.staticComponents.toList() ?? [];
    dynamicComponents = e?.dynamicComponents.toList() ?? [];
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final std = StandardDef(
        code: code.text.trim(),
        name: name.text.trim(),
        parameters: parameters,
        staticComponents: staticComponents,
        dynamicComponents: dynamicComponents,
      );
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
            ...parameters
                .asMap()
                .entries
                .map(
                  (e) => _ParameterEditor(
                    def: e.value,
                    onChanged:
                        (p) => setState(() {
                          parameters[e.key] = p;
                        }),
                    onDelete:
                        () => setState(() {
                          parameters.removeAt(e.key);
                        }),
                  ),
                )
                .toList(),
            TextButton.icon(
              onPressed:
                  () => setState(() {
                    parameters.add(ParameterDef(key: '', type: ParamType.text));
                  }),
              icon: const Icon(Icons.add),
              label: const Text('Add Parameter'),
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
                    onEditRules: () => _openRuleWizard(e.key),
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

class _ParameterEditor extends StatefulWidget {
  final ParameterDef def;
  final ValueChanged<ParameterDef> onChanged;
  final VoidCallback onDelete;

  const _ParameterEditor({
    required this.def,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_ParameterEditor> createState() => _ParameterEditorState();
}

class _ParameterEditorState extends State<_ParameterEditor> {
  late TextEditingController key;
  late TextEditingController unit;
  late TextEditingController allowed;
  late bool requiredField;
  late ParamType type;

  @override
  void initState() {
    super.initState();
    key = TextEditingController(text: widget.def.key);
    unit = TextEditingController(text: widget.def.unit ?? '');
    allowed = TextEditingController(text: widget.def.allowedValues.join(','));
    requiredField = widget.def.required;
    type = widget.def.type;
  }

  void _notify() {
    widget.onChanged(
      ParameterDef(
        key: key.text.trim(),
        type: type,
        unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
        allowedValues:
            allowed.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
        required: requiredField,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: key,
                    decoration: const InputDecoration(labelText: 'Key'),
                    onChanged: (_) => _notify(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<ParamType>(
                  value: type,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        type = v;
                      });
                      _notify();
                    }
                  },
                  items:
                      ParamType.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(paramTypeToString(e)),
                            ),
                          )
                          .toList(),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    onChanged: (_) => _notify(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: allowed,
                    decoration: const InputDecoration(
                      labelText: 'Allowed Values (comma)',
                    ),
                    onChanged: (_) => _notify(),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: requiredField,
                  onChanged: (v) {
                    setState(() {
                      requiredField = v ?? false;
                    });
                    _notify();
                  },
                ),
                const Text('Required'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    key.dispose();
    unit.dispose();
    allowed.dispose();
    super.dispose();
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
