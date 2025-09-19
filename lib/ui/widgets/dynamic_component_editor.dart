import 'package:flutter/material.dart';

import '../../core/models.dart';

class DynamicComponentEditor extends StatefulWidget {
  final DynamicComponentDef comp;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onEditRules;
  final VoidCallback onDelete;

  const DynamicComponentEditor({
    super.key,
    required this.comp,
    required this.onNameChanged,
    required this.onEditRules,
    required this.onDelete,
  });

  @override
  State<DynamicComponentEditor> createState() => _DynamicComponentEditorState();
}

class _DynamicComponentEditorState extends State<DynamicComponentEditor> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.comp.name);
  }

  @override
  void didUpdateWidget(covariant DynamicComponentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comp.name != widget.comp.name &&
        _nameController.text != widget.comp.name) {
      _nameController.text = widget.comp.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
                controller: _nameController,
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
}
