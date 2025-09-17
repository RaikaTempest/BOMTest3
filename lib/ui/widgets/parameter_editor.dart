import 'package:flutter/material.dart';

import '../../core/models.dart';

class ParameterEditor extends StatefulWidget {
  final ParameterDef def;
  final ValueChanged<ParameterDef> onChanged;
  final VoidCallback onDelete;

  const ParameterEditor({
    super.key,
    required this.def,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<ParameterEditor> createState() => _ParameterEditorState();
}

class _ParameterEditorState extends State<ParameterEditor> {
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

  @override
  void didUpdateWidget(covariant ParameterEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.def.key != widget.def.key) {
      key.text = widget.def.key;
    }
    final oldUnit = oldWidget.def.unit ?? '';
    final newUnit = widget.def.unit ?? '';
    if (oldUnit != newUnit) {
      unit.text = newUnit;
    }
    if (oldWidget.def.type != widget.def.type) {
      type = widget.def.type;
    }
    if (oldWidget.def.required != widget.def.required) {
      requiredField = widget.def.required;
    }
    if (oldWidget.def.allowedValues.join(',') !=
        widget.def.allowedValues.join(',')) {
      allowed.text = widget.def.allowedValues.join(',');
    }
  }

  void _notify() {
    widget.onChanged(
      ParameterDef(
        key: key.text.trim(),
        type: type,
        unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
        allowedValues: allowed.text
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
                  items: ParamType.values
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
