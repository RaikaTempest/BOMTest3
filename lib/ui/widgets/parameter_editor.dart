import 'package:flutter/material.dart';

import '../../core/models.dart';

class ParameterEditor extends StatefulWidget {
  final ParameterDef def;
  final ValueChanged<ParameterDef> onChanged;
  final VoidCallback onDelete;
  final List<String> keySuggestions;

  const ParameterEditor({
    super.key,
    required this.def,
    required this.onChanged,
    required this.onDelete,
    this.keySuggestions = const [],
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
  late FocusNode _keyFocusNode;

  @override
  void initState() {
    super.initState();
    key = TextEditingController(text: widget.def.key);
    unit = TextEditingController(text: widget.def.unit ?? '');
    allowed = TextEditingController(text: widget.def.allowedValues.join(','));
    requiredField = widget.def.required;
    type = widget.def.type;
    _keyFocusNode = FocusNode();
  }

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
  void didUpdateWidget(covariant ParameterEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.def.key != widget.def.key) {
      _syncController(key, widget.def.key);
    }
    final oldUnit = oldWidget.def.unit ?? '';
    final newUnit = widget.def.unit ?? '';
    if (oldUnit != newUnit) {
      _syncController(unit, newUnit);
    }
    if (oldWidget.def.type != widget.def.type) {
      type = widget.def.type;
    }
    if (oldWidget.def.required != widget.def.required) {
      requiredField = widget.def.required;
    }
    if (oldWidget.def.allowedValues.join(',') !=
        widget.def.allowedValues.join(',')) {
      _syncController(allowed, widget.def.allowedValues.join(','));
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RawAutocomplete<String>(
                textEditingController: key,
                focusNode: _keyFocusNode,
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.trim();
                  if (query.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  final lower = query.toLowerCase();
                  final seen = <String>{};
                  return widget.keySuggestions.where((option) {
                    if (!seen.add(option)) return false;
                    if (option.toLowerCase() == lower) return false;
                    return option.toLowerCase().contains(lower);
                  });
                },
                onSelected: (selection) {
                  _syncController(key, selection);
                  _notify();
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Key'),
                    onChanged: (_) => _notify(),
                    onEditingComplete: onFieldSubmitted,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final theme = Theme.of(context);
                  return Align(
                    alignment: Alignment.bottomLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxHeight: 200, minWidth: 200),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: options
                              .map(
                                (option) => ListTile(
                                  title: Text(
                                    option,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  onTap: () => onSelected(option),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<ParamType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ParamType.values
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(paramTypeToString(e)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      type = v;
                    });
                    _notify();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Remove parameter',
              child: IconButton.filledTonal(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                onChanged: (_) => _notify(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: allowed,
                decoration: const InputDecoration(
                  labelText: 'Allowed values (comma separated)',
                ),
                onChanged: (_) => _notify(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
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
              const SizedBox(width: 8),
              Text(
                'Required',
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              if (type == ParamType.enumType)
                Text(
                  'Separate multiple values with commas',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white.withOpacity(0.6)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _keyFocusNode.dispose();
    key.dispose();
    unit.dispose();
    allowed.dispose();
    super.dispose();
  }
}
