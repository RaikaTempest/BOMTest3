import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/models.dart';
import 'rule_wizard.dart';

class DynamicComponentRulesScreen extends StatefulWidget {
  final DynamicComponentDef component;
  final List<ParameterDef> parameters;

  const DynamicComponentRulesScreen({
    super.key,
    required this.component,
    required this.parameters,
  });

  @override
  State<DynamicComponentRulesScreen> createState() =>
      _DynamicComponentRulesScreenState();
}

class _DynamicComponentRulesScreenState
    extends State<DynamicComponentRulesScreen> {
  late List<RuleDef> _rules;

  @override
  void initState() {
    super.initState();
    _rules = widget.component.rules.map((e) => e).toList();
  }

  Future<void> _addRule() async {
    final created = await Navigator.of(context).push<RuleDef>(
      MaterialPageRoute(
        builder: (_) => RuleWizard(parameters: widget.parameters),
      ),
    );
    if (created != null) {
      setState(() {
        _rules.add(created);
        _sortRules();
      });
    }
  }

  Future<void> _editRule(int index) async {
    final updated = await Navigator.of(context).push<RuleDef>(
      MaterialPageRoute(
        builder: (_) => RuleWizard(
          existing: _rules[index],
          parameters: widget.parameters,
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        _rules[index] = updated;
        _sortRules();
      });
    }
  }

  void _deleteRule(int index) {
    setState(() {
      _rules.removeAt(index);
    });
  }

  void _sortRules() {
    _rules.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      final exprLengthA = jsonEncode(a.expr).length;
      final exprLengthB = jsonEncode(b.expr).length;
      return exprLengthB.compareTo(exprLengthA);
    });
  }

  void _finish() {
    final updated = DynamicComponentDef(
      name: widget.component.name,
      selectionStrategy: widget.component.selectionStrategy,
      rules: List<RuleDef>.from(_rules),
    );
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  String _exprSummary(Map<String, dynamic> expr) {
    return jsonEncode(expr);
  }

  String _outputsSummary(List<OutputSpec> outputs) {
    if (outputs.isEmpty) {
      return 'None';
    }
    return outputs.map((o) {
      final buffer = StringBuffer(o.mm);
      if (o.qty != null) {
        buffer.write(' × ${o.qty}');
      } else if (o.qtyFormula != null && o.qtyFormula!.isNotEmpty) {
        buffer.write(' × ${o.qtyFormula}');
      }
      return buffer.toString();
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final componentName =
        widget.component.name.isEmpty ? 'Dynamic Component' : widget.component.name;

    return WillPopScope(
      onWillPop: () async {
        _finish();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Rules — $componentName'),
          actions: [
            TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: _rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No rules defined yet.'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _addRule,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Rule'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    for (final entry in _rules.asMap().entries)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rule ${entry.key + 1}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text('Priority: ${entry.value.priority}'),
                              const SizedBox(height: 4),
                              Text('When: ${_exprSummary(entry.value.expr)}'),
                              const SizedBox(height: 4),
                              Text('Outputs: ${_outputsSummary(entry.value.outputs)}'),
                              ButtonBar(
                                alignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _editRule(entry.key),
                                    child: const Text('Edit'),
                                  ),
                                  TextButton(
                                    onPressed: () => _deleteRule(entry.key),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        floatingActionButton: _rules.isEmpty
            ? null
            : FloatingActionButton(
                onPressed: _addRule,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}
