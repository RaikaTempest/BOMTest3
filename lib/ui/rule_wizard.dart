import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/models.dart';

class RuleWizard extends StatefulWidget {
  final DynamicComponentDef parent;
  final RuleDef? existing;

  const RuleWizard({super.key, required this.parent, this.existing});

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

class _RuleWizardState extends State<RuleWizard> {
  late final TextEditingController priority;
  late final TextEditingController expr;
  final List<_OutputFields> _outputs = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    priority =
        TextEditingController(text: e?.priority.toString() ?? '0');
    expr = TextEditingController(
        text: e == null ? '{}' : jsonEncode(e.expr));
    final outputs = e?.outputs.isNotEmpty == true
        ? e!.outputs
        : [OutputSpec(mm: '', qty: null, qtyFormula: null)];
    for (final o in outputs) {
      _outputs.add(_OutputFields(
          mm: o.mm, qty: o.qty, qtyFormula: o.qtyFormula));
    }
  }

  @override
  void dispose() {
    priority.dispose();
    expr.dispose();
    for (final o in _outputs) {
      o.dispose();
    }
    super.dispose();
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

  Future<void> _save() async {
    try {
      final rule = RuleDef(
        expr: (jsonDecode(expr.text) as Map).cast<String, dynamic>(),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save error: $e')));
    }
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
              decoration:
                  const InputDecoration(labelText: 'Qty (optional)'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: f.qtyFormula,
              decoration: const InputDecoration(
                  labelText: 'Qty Formula (optional)'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Rule' : 'Edit Rule'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
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
            TextField(
              controller: expr,
              decoration: const InputDecoration(
                labelText: 'Expression (JSONLogic)',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            const Text('Outputs'),
            const SizedBox(height: 4),
            ..._outputs.asMap().entries
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
    );
  }
}

