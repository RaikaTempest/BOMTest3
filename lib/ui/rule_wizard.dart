import 'package:flutter/material.dart';

import '../core/models.dart';

class RuleWizard extends StatefulWidget {
  final DynamicComponentDef parent;
  final RuleDef? existing;
  final List<ParameterDef> parameters;

  const RuleWizard({
    super.key,
    required this.parent,
    this.existing,
    required this.parameters,
  });

  @override
  State<RuleWizard> createState() => _RuleWizardState();
}

class _OutputFields {
  final TextEditingController mm = TextEditingController();
  final TextEditingController qty = TextEditingController();
  final TextEditingController qtyFormula = TextEditingController();

  _OutputFields({String? mm, int? qty, String? qtyFormula}) {
    this.mm.text = mm ?? '';
    this.qty.text = qty?.toString() ?? '';
    this.qtyFormula.text = qtyFormula ?? '';
  }

  void dispose() {
    mm.dispose();
    qty.dispose();
    qtyFormula.dispose();
  }

  OutputSpec toOutputSpec() {
    final mmValue = mm.text.trim();
    final qtyText = qty.text.trim();
    final formulaText = qtyFormula.text.trim();
    return OutputSpec(
      mm: mmValue,
      qty: qtyText.isEmpty ? null : int.tryParse(qtyText),
      qtyFormula: formulaText.isEmpty ? null : formulaText,
    );
  }
}

class _ConditionFields {
  final TextEditingController param = TextEditingController();
  String op;
  final TextEditingController value = TextEditingController();

  _ConditionFields({String? param, this.op = '==', String? value}) {
    this.param.text = param ?? '';
    this.value.text = value ?? '';
  }

  void dispose() {
    param.dispose();
    value.dispose();
  }

  Map<String, dynamic> toJsonLogic() {
    final valText = value.text.trim();
    dynamic val = int.tryParse(valText);
    val ??= double.tryParse(valText);
    if (val == null) {
      final lower = valText.toLowerCase();
      if (lower == 'true' || lower == 'false') {
        val = lower == 'true';
      } else {
        val = valText;
      }
    }
    return {
      op: [
        {'var': param.text.trim()},
        val,
      ],
    };
  }
}

class _RuleWizardState extends State<RuleWizard> {
  late final TextEditingController priority;
  final List<_ConditionFields> _conditions = [];
  final List<_OutputFields> _outputs = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    priority = TextEditingController(text: e?.priority.toString() ?? '0');

    if (e != null) {
      _loadExpr(e.expr);
    }
    if (_conditions.isEmpty) {
      _conditions.add(_ConditionFields());
    }

    final outputs =
        e?.outputs.isNotEmpty == true
            ? e!.outputs
            : [OutputSpec(mm: '', qty: null, qtyFormula: null)];
    for (final o in outputs) {
      _outputs.add(
        _OutputFields(mm: o.mm, qty: o.qty, qtyFormula: o.qtyFormula),
      );
    }
  }

  @override
  void dispose() {
    priority.dispose();
    for (final c in _conditions) {
      c.dispose();
    }
    for (final o in _outputs) {
      o.dispose();
    }
    super.dispose();
  }

  void _addCondition() {
    setState(() {
      _conditions.add(_ConditionFields());
    });
  }

  void _removeCondition(int index) {
    setState(() {
      _conditions.removeAt(index);
    });
  }

  void _addOutput() {
    setState(() {
      _outputs.add(_OutputFields());
    });
  }

  void _removeOutput(int index) {
    setState(() {
      _outputs.removeAt(index);
    });
  }

  Future<void> _addParameterDialog({String initialKey = ''}) async {
    final keyCtrl = TextEditingController(text: initialKey);
    final unitCtrl = TextEditingController();
    final allowedCtrl = TextEditingController();
    bool requiredField = true;
    ParamType type = ParamType.text;

    final result = await showDialog<ParameterDef>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New Variable'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: keyCtrl,
                      decoration: const InputDecoration(labelText: 'Key'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<ParamType>(
                      value: type,
                      onChanged: (v) {
                        if (v != null) setState(() => type = v);
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: allowedCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Allowed Values (comma)',
                      ),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: requiredField,
                          onChanged:
                              (v) => setState(() => requiredField = v ?? false),
                        ),
                        const Text('Required'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      ParameterDef(
                        key: keyCtrl.text.trim(),
                        type: type,
                        unit:
                            unitCtrl.text.trim().isEmpty
                                ? null
                                : unitCtrl.text.trim(),
                        allowedValues:
                            allowedCtrl.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList(),
                        required: requiredField,
                      ),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    keyCtrl.dispose();
    unitCtrl.dispose();
    allowedCtrl.dispose();

    if (result != null) {
      setState(() {
        widget.parameters.add(result);
      });
    }
  }

  Future<void> _save() async {
    try {
      final conds = _conditions.map((e) => e.toJsonLogic()).toList();
      final Map<String, dynamic> expr =
          conds.length == 1 ? conds.first : {'and': conds};
      final rule = RuleDef(
        expr: expr,
        outputs: _outputs.map((e) => e.toOutputSpec()).toList(),
        priority: int.tryParse(priority.text) ?? 0,
      );

      final existing = widget.existing;
      final rules = widget.parent.rules;
      if (existing != null) {
        final index = rules.indexOf(existing);
        if (index >= 0) {
          rules[index] = rule;
        } else {
          rules.add(rule);
        }
      } else {
        rules.add(rule);
      }

      if (!mounted) return;
      Navigator.of(context).pop(widget.parent);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save error: $e')));
    }
  }

  Widget _buildCondition(_ConditionFields f, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                return widget.parameters
                    .map((e) => e.key)
                    .where(
                      (k) => k.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ),
                    );
              },
              initialValue: TextEditingValue(text: f.param.text),
              fieldViewBuilder: (
                context,
                controller,
                focusNode,
                onFieldSubmitted,
              ) {
                controller.text = f.param.text;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Param'),
                  onChanged: (v) => f.param.text = v,
                );
              },
              onSelected: (selection) {
                f.param.text = selection;
              },
            ),
          ),
          IconButton(
            onPressed:
                () => _addParameterDialog(initialKey: f.param.text.trim()),
            icon: const Icon(Icons.add),
            tooltip: 'Add variable',
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: f.op,
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  f.op = v;
                });
              }
            },
            items:
                const ['==', '!=', '>', '>=', '<', '<=']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: f.value,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
          ),
          IconButton(
            onPressed: () => _removeCondition(index),
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildOutput(_OutputFields f, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: f.mm,
              decoration: const InputDecoration(labelText: 'MM'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: f.qty,

              decoration: const InputDecoration(labelText: 'Qty (optional)'),

              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: f.qtyFormula,
              decoration: const InputDecoration(
                labelText: 'Qty Formula (optional)',
              ),
            ),
          ),
          IconButton(
            onPressed: () => _removeOutput(index),
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
    );
  }

  void _loadExpr(Map<String, dynamic> expr) {
    _conditions.clear();
    Map<String, dynamic> m = expr;
    if (m.containsKey('and')) {
      final list = m['and'] as List;
      for (final e in list) {
        _conditions.add(_conditionFromExpr((e as Map).cast<String, dynamic>()));
      }
    } else {
      _conditions.add(_conditionFromExpr(m));
    }
  }

  _ConditionFields _conditionFromExpr(Map<String, dynamic> m) {
    if (m.isEmpty) return _ConditionFields();
    final op = m.keys.first;
    final args = m[op] as List;
    String param = '';
    String value = '';
    if (args.isNotEmpty) {
      final first = args[0];
      if (first is Map && first['var'] is String) {
        param = first['var'] as String;
      }
      if (args.length > 1) {
        value = '${args[1]}';
      }
    }
    return _ConditionFields(param: param, op: op, value: value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Rule' : 'Edit Rule'),
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
              controller: priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            const Text('Variables'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children:
                  widget.parameters
                      .map((e) => Chip(label: Text(e.key)))
                      .toList(),
            ),
            TextButton.icon(
              onPressed: _addParameterDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Variable'),
            ),
            const SizedBox(height: 8),
            const Text('Conditions'),
            const SizedBox(height: 4),
            ..._conditions
                .asMap()
                .entries
                .map((e) => _buildCondition(e.value, e.key))
                .toList(),
            TextButton.icon(
              onPressed: _addCondition,
              icon: const Icon(Icons.add),
              label: const Text('Add Condition'),
            ),
            const SizedBox(height: 8),
            const Text('Outputs'),
            const SizedBox(height: 4),
            ..._outputs
                .asMap()
                .entries
                .map((e) => _buildOutput(e.value, e.key))
                .toList(),
            TextButton.icon(
              onPressed: _addOutput,
              icon: const Icon(Icons.add),
              label: const Text('Add Output'),
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
