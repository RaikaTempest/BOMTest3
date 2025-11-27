import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
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
  late ConnectorMatrix _matrix;
  late Set<String> _matrixColumns;
  late TextEditingController _axis1Controller;
  late TextEditingController _axis2Controller;
  late TextEditingController _mmPatternController;
  late FocusNode _axis1FocusNode;
  late FocusNode _axis2FocusNode;
  bool _suspendAxisListeners = false;

  @override
  void initState() {
    super.initState();
    _rules = widget.component.rules.map((e) => e).toList();
    final existingMatrix = widget.component.matrix ??
        const ConnectorMatrix(axis1Parameter: '', axis2Parameter: '', rows: []);
    _matrix = existingMatrix;
    _matrixColumns = {...existingMatrix.columnValues};
    _axis1Controller =
        TextEditingController(text: existingMatrix.axis1Parameter);
    _axis2Controller =
        TextEditingController(text: existingMatrix.axis2Parameter);
    _mmPatternController =
        TextEditingController(text: widget.component.mmPattern ?? '');
    _axis1FocusNode = FocusNode();
    _axis2FocusNode = FocusNode();
    _axis1Controller.addListener(_handleAxisControllersChanged);
    _axis2Controller.addListener(_handleAxisControllersChanged);
  }

  @override
  void dispose() {
    _axis1Controller.removeListener(_handleAxisControllersChanged);
    _axis2Controller.removeListener(_handleAxisControllersChanged);
    _axis1Controller.dispose();
    _axis2Controller.dispose();
    _mmPatternController.dispose();
    _axis1FocusNode.dispose();
    _axis2FocusNode.dispose();
    super.dispose();
  }

  List<String> _allParameterKeys() {
    final keys = <String>{};
    for (final parameter in widget.parameters) {
      final key = parameter.key.trim();
      if (key.isEmpty) continue;
      keys.add(key);
    }
    final sorted = keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Iterable<String> _parameterSuggestions(String query) {
    final keys = _allParameterKeys();
    if (keys.isEmpty) {
      return const Iterable<String>.empty();
    }
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return keys;
    }
    final lower = trimmed.toLowerCase();
    return keys.where((key) => key.toLowerCase().contains(lower));
  }

  Widget _buildAxisField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String helperText,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (textEditingValue) {
        return _parameterSuggestions(textEditingValue.text);
      },
      displayStringForOption: (option) => option,
      fieldViewBuilder:
          (context, textEditingController, fieldFocusNode, onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: fieldFocusNode,
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
          ),
          onEditingComplete: onFieldSubmitted,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList();
        if (optionList.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: optionList.length,
                itemBuilder: (context, index) {
                  final option = optionList[index];
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (selection) {
        controller.selection =
            TextSelection.collapsed(offset: selection.length);
      },
    );
  }

  void _handleAxisControllersChanged() {
    if (_suspendAxisListeners) return;
    final axis1 = _axis1Controller.text.trim();
    final axis2 = _axis2Controller.text.trim();
    setState(() {
      _matrix = _matrix.copyWith(
        axis1Parameter: axis1,
        axis2Parameter: axis2,
      );
    });
  }

  void _updateMatrix(ConnectorMatrix newMatrix, {bool updateControllers = false}) {
    setState(() {
      _matrix = newMatrix;
      _matrixColumns = {...newMatrix.columnValues};
    });
    if (updateControllers) {
      _suspendAxisListeners = true;
      _axis1Controller.text = newMatrix.axis1Parameter;
      _axis2Controller.text = newMatrix.axis2Parameter;
      _suspendAxisListeners = false;
    }
  }

  List<String> _sortedColumns() {
    final list = _matrixColumns.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> _parseMatrixMmInput(String raw) {
    if (raw.trim().isEmpty) return const [];
    final parts = raw.split(RegExp(r'[\n,;|]+'));
    final seen = <String>{};
    final result = <String>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed)) {
        result.add(trimmed);
      }
    }
    return result;
  }

  ConnectorMatrix? _matrixForSave() {
    final rows = <ConnectorMatrixRow>[];
    for (final row in _matrix.rows) {
      final cleanedCells = <ConnectorMatrixCell>[];
      for (final cell in row.cells) {
        final hasData = cell.hasMm ||
            !cell.enabled ||
            cell.requiresAccessory ||
            (cell.notes != null && cell.notes!.trim().isNotEmpty) ||
            cell.qty != 1;
        if (hasData) {
          cleanedCells.add(cell);
        }
      }
      if (cleanedCells.isNotEmpty) {
        rows.add(row.copyWith(cells: cleanedCells));
      }
    }
    final cleaned = _matrix.copyWith(rows: rows);
    final hasAxisNames = cleaned.axis1Parameter.trim().isNotEmpty ||
        cleaned.axis2Parameter.trim().isNotEmpty;
    if (cleaned.rows.isEmpty && !hasAxisNames) {
      return null;
    }
    return cleaned;
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

  void _addAxis1Value() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            'Add ${_matrix.axis1Parameter.isEmpty ? 'Row' : _matrix.axis1Parameter} value'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. 1/0'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(context).pop();
              if (value.isEmpty) return;
              final lower = value.toLowerCase();
              if (_matrix.rows
                  .any((row) => row.axis1Value.toLowerCase() == lower)) {
                return;
              }
              final columns = _sortedColumns();
              final cells = [
                for (final column in columns)
                  ConnectorMatrixCell(axis2Value: column),
              ];
              final rows = [..._matrix.rows, ConnectorMatrixRow(axis1Value: value, cells: cells)]
                ..sort((a, b) => a.axis1Value
                    .toLowerCase()
                    .compareTo(b.axis1Value.toLowerCase()));
              _updateMatrix(_matrix.copyWith(rows: rows));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeAxis1Value(String value) {
    final lower = value.toLowerCase();
    final rows = _matrix.rows
        .where((row) => row.axis1Value.toLowerCase() != lower)
        .toList();
    _updateMatrix(_matrix.copyWith(rows: rows));
  }

  void _addAxis2Value() {
    if (_matrix.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one row before adding columns.')),
      );
      return;
    }
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            'Add ${_matrix.axis2Parameter.isEmpty ? 'Column' : _matrix.axis2Parameter} value'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. 2/0'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(context).pop();
              if (value.isEmpty) return;
              final lower = value.toLowerCase();
              if (_matrixColumns.any((c) => c.toLowerCase() == lower)) {
                return;
              }
              final updatedRows = <ConnectorMatrixRow>[];
              for (final row in _matrix.rows) {
                final cells = [...row.cells];
                if (!cells.any(
                    (cell) => cell.axis2Value.toLowerCase() == lower)) {
                  cells.add(ConnectorMatrixCell(axis2Value: value));
                  cells.sort((a, b) => a.axis2Value
                      .toLowerCase()
                      .compareTo(b.axis2Value.toLowerCase()));
                }
                updatedRows.add(row.copyWith(cells: cells));
              }
              _matrixColumns.add(value);
              _updateMatrix(_matrix.copyWith(rows: updatedRows));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeAxis2Value(String value) {
    final lower = value.toLowerCase();
    final updatedRows = <ConnectorMatrixRow>[];
    for (final row in _matrix.rows) {
      final filtered = row.cells
          .where((cell) => cell.axis2Value.toLowerCase() != lower)
          .toList();
      updatedRows.add(row.copyWith(cells: filtered));
    }
    _matrixColumns.removeWhere((c) => c.toLowerCase() == lower);
    _updateMatrix(_matrix.copyWith(rows: updatedRows));
  }

  ConnectorMatrixCell _findCell(String rowValue, String columnValue) {
    final lowerColumn = columnValue.toLowerCase();
    final row = _matrix.rows.firstWhere(
      (r) => r.axis1Value.toLowerCase() == rowValue.toLowerCase(),
      orElse: () => ConnectorMatrixRow(axis1Value: rowValue),
    );
    return row.cells.firstWhere(
      (cell) => cell.axis2Value.toLowerCase() == lowerColumn,
      orElse: () => ConnectorMatrixCell(axis2Value: columnValue),
    );
  }

  void _setCell(String rowValue, String columnValue, ConnectorMatrixCell cell) {
    final updatedRows = <ConnectorMatrixRow>[];
    final targetLower = rowValue.toLowerCase();
    final columnLower = columnValue.toLowerCase();
    for (final row in _matrix.rows) {
      if (row.axis1Value.toLowerCase() != targetLower) {
        updatedRows.add(row);
        continue;
      }
      final cells = [...row.cells];
      final idx = cells.indexWhere(
          (c) => c.axis2Value.toLowerCase() == columnLower);
      if (idx >= 0) {
        cells[idx] = cell;
      } else {
        cells.add(cell);
      }
      cells.sort((a, b) => a.axis2Value
          .toLowerCase()
          .compareTo(b.axis2Value.toLowerCase()));
      updatedRows.add(row.copyWith(cells: cells));
    }
    _matrixColumns.add(columnValue);
    _updateMatrix(_matrix.copyWith(rows: updatedRows));
  }

  Future<void> _editCell(String rowValue, String columnValue) async {
    final existing = _findCell(rowValue, columnValue);
    final mmController =
        TextEditingController(text: existing.mms.join('\n'));
    final qtyController = TextEditingController(text: existing.qty.toString());
    final notesController = TextEditingController(text: existing.notes ?? '');
    var enabled = existing.enabled;
    var requiresAccessory = existing.requiresAccessory;

    final updated = await showDialog<ConnectorMatrixCell>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit $rowValue × $columnValue'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: mmController,
                      decoration: const InputDecoration(
                        labelText: 'Part numbers',
                        helperText: 'Enter one part number per line',
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                    TextField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                    ),
                    SwitchListTile(
                      title: const Text('Combination enabled'),
                      value: enabled,
                      onChanged: (v) => setState(() => enabled = v),
                    ),
                    CheckboxListTile(
                      value: requiresAccessory,
                      onChanged: (v) => setState(() => requiresAccessory = v ?? false),
                      title: const Text('Requires accessory'),
                    ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    mmController.clear();
                    qtyController.text = '1';
                    notesController.clear();
                    enabled = true;
                    requiresAccessory = false;
                    setState(() {});
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final qty = int.tryParse(qtyController.text.trim());
                    final mms = _parseMatrixMmInput(mmController.text);
                    Navigator.of(context).pop(
                      ConnectorMatrixCell(
                        axis2Value: columnValue,
                        mms: mms,
                        qty: qty ?? 1,
                        enabled: enabled,
                        requiresAccessory: requiresAccessory,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated != null) {
      _setCell(rowValue, columnValue, updated);
    }
  }

  String _matrixToCsv() {
    final sb = StringBuffer();
    final columns = _sortedColumns();
    sb.writeln(
        '${_csvEscape(_matrix.axis1Parameter.isEmpty ? 'axis1' : _matrix.axis1Parameter)},${_csvEscape(_matrix.axis2Parameter.isEmpty ? 'axis2' : _matrix.axis2Parameter)},mm,qty,enabled,requires_accessory,notes');
    for (final row in _matrix.rows) {
      for (final column in columns) {
        final cell = _findCell(row.axis1Value, column);
        final line = [
          _csvEscape(row.axis1Value),
          _csvEscape(column),
          _csvEscape(cell.mms.join(' | ')),
          _csvEscape(cell.qty.toString()),
          _csvEscape(cell.enabled ? 'true' : 'false'),
          _csvEscape(cell.requiresAccessory ? 'true' : 'false'),
          _csvEscape(cell.notes ?? ''),
        ].join(',');
        sb.writeln(line);
      }
    }
    return sb.toString();
  }

  void _importMatrixFromCsv(String csv) {
    final trimmed = csv.trim();
    if (trimmed.isEmpty) return;
    final lines = const LineSplitter().convert(trimmed);
    if (lines.isEmpty) return;
    final rowsByAxis1 = <String, List<ConnectorMatrixCell>>{};
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = _splitCsvLine(line);
      if (parts.length < 2) continue;
      final axis1 = parts[0].trim();
      final axis2 = parts[1].trim();
      if (axis1.isEmpty || axis2.isEmpty) {
        continue;
      }
      final mmField = parts.length > 2 ? parts[2].trim() : '';
      final mms = _parseMatrixMmInput(mmField);
      final qtyString = parts.length > 3 ? parts[3].trim() : '1';
      final enabledString = parts.length > 4 ? parts[4].trim() : 'true';
      final requiresAccessoryString =
          parts.length > 5 ? parts[5].trim() : 'false';
      final notes = parts.length > 6 ? parts[6].trim() : '';
      final qty = int.tryParse(qtyString) ?? 1;
      final enabled = enabledString.toLowerCase() != 'false';
      final requiresAccessory = requiresAccessoryString.toLowerCase() == 'true';
      rowsByAxis1.putIfAbsent(axis1, () => <ConnectorMatrixCell>[]).add(
            ConnectorMatrixCell(
              axis2Value: axis2,
              mms: mms,
              qty: qty,
              enabled: enabled,
              requiresAccessory: requiresAccessory,
              notes: notes.isEmpty ? null : notes,
            ),
          );
    }
    final rows = <ConnectorMatrixRow>[];
    for (final entry in rowsByAxis1.entries) {
      entry.value.sort((a, b) =>
          a.axis2Value.toLowerCase().compareTo(b.axis2Value.toLowerCase()));
      rows.add(ConnectorMatrixRow(axis1Value: entry.key, cells: entry.value));
    }
    rows.sort((a, b) => a.axis1Value.toLowerCase().compareTo(b.axis1Value.toLowerCase()));
    _updateMatrix(_matrix.copyWith(rows: rows));
  }

  Future<void> _exportMatrixCsv() async {
    final csv = _matrixToCsv();
    final suggestedName = _suggestedMatrixFilename();
    try {
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'CSV',
            extensions: ['csv'],
          ),
        ],
      );
      final path = location?.path;
      if (path == null) {
        return;
      }
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
        name: suggestedName,
      );
      await file.saveTo(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Matrix exported to $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export matrix: $e')),
      );
    }
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import matrix CSV'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Paste CSV content here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(context).pop();
              if (text.isEmpty) return;
              _importMatrixFromCsv(text);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  List<String> _splitCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString());
    return values;
  }

  void _finish() {
    final matrix = _matrixForSave();
    final pattern = _mmPatternController.text.trim();
    final updated = DynamicComponentDef(
      name: widget.component.name,
      selectionStrategy: widget.component.selectionStrategy,
      rules: List<RuleDef>.from(_rules),
      matrix: matrix,
      mmPattern: pattern.isEmpty ? null : pattern,
    );
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final componentName =
        widget.component.name.isEmpty ? 'Dynamic Component' : widget.component.name;

    return DefaultTabController(
      length: 2,
      child: WillPopScope(
        onWillPop: () async {
          _finish();
          return false;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text('Rules — $componentName'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'import':
                      _showImportDialog();
                      break;
                    case 'export':
                      _exportMatrixCsv();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'import', child: Text('Import matrix CSV')),
                  PopupMenuItem(value: 'export', child: Text('Export matrix CSV')),
                ],
              ),
              TextButton(
                onPressed: _finish,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Rules'),
                Tab(text: 'Matrix'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildRulesTab(),
              _buildMatrixTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatrixTab() {
    final columns = _sortedColumns();
    final axis1Label =
        _matrix.axis1Parameter.isEmpty ? 'First axis parameter key' : _matrix.axis1Parameter;
    final axis2Label =
        _matrix.axis2Parameter.isEmpty ? 'Second axis parameter key' : _matrix.axis2Parameter;
    final axis1Display =
        _matrix.axis1Parameter.isEmpty ? 'row' : _matrix.axis1Parameter;
    final axis2Display =
        _matrix.axis2Parameter.isEmpty ? 'column' : _matrix.axis2Parameter;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Define wire combinations using the matrix. Each cell can hold a part number, quantity, notes, and whether the combo is allowed.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAxisField(
                  controller: _axis1Controller,
                  focusNode: _axis1FocusNode,
                  label: 'First axis parameter key',
                  helperText:
                      'Matches a parameter in the job form (e.g., wire_1)',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAxisField(
                  controller: _axis2Controller,
                  focusNode: _axis2FocusNode,
                  label: 'Second axis parameter key',
                  helperText:
                      'Matches a parameter in the job form (e.g., wire_2)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mmPatternController,
            decoration: const InputDecoration(
              labelText: 'Optional SKU pattern',
              helperText: 'Use placeholders like {axis1}, {axis2}, or any parameter key.',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _addAxis1Value,
                icon: const Icon(Icons.table_rows),
                label: Text('Add $axis1Display value'),
              ),
              ElevatedButton.icon(
                onPressed: _addAxis2Value,
                icon: const Icon(Icons.table_chart),
                label: Text('Add $axis2Display value'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _matrix.rows.isEmpty
                ? Center(
                    child: Text(
                      'No combinations yet. Add $axis1Display values and $axis2Display values to begin.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(axis1Label.isEmpty ? 'Row' : axis1Label)),
                          for (final column in columns)
                            DataColumn(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(column),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    tooltip: 'Remove $column',
                                    onPressed: () => _removeAxis2Value(column),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        rows: [
                          for (final row in _matrix.rows)
                            DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            row.axis1Value,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16),
                                          tooltip: 'Remove ${row.axis1Value}',
                                          onPressed: () => _removeAxis1Value(row.axis1Value),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                for (final column in columns)
                                  _buildMatrixCell(row.axis1Value, column),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  DataCell _buildMatrixCell(String rowValue, String columnValue) {
    final cell = _findCell(rowValue, columnValue);
    final content = <Widget>[];
    if (!cell.enabled) {
      content.add(const Icon(Icons.block, size: 18, color: Colors.redAccent));
    }
    if (cell.mms.isNotEmpty) {
      for (final mm in cell.mms) {
        content.add(
          Text(mm, style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      }
    }
    if (cell.requiresAccessory) {
      content.add(const Text('Accessory required', style: TextStyle(fontSize: 11)));
    }
    if (cell.notes != null && cell.notes!.isNotEmpty) {
      content.add(Text(cell.notes!, style: const TextStyle(fontSize: 11)));
    }
    if (content.isEmpty) {
      content.add(const Text('—', style: TextStyle(color: Colors.grey)));
    }
    return DataCell(
      InkWell(
        onTap: () => _editCell(rowValue, columnValue),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
        ),
      ),
    );
  }

  Widget _buildRulesTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _rules.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No advanced rules defined yet.'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addRule,
                    icon: const Icon(Icons.add),
                    label: const Text('Add rule'),
                  ),
                ],
              ),
            )
          : ListView(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _addRule,
                    icon: const Icon(Icons.add),
                    label: const Text('Add rule'),
                  ),
                ),
                const SizedBox(height: 12),
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
    );
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

  String _suggestedMatrixFilename() {
    final name = widget.component.name.trim();
    final sanitized = name.isEmpty
        ? 'dynamic_component_matrix'
        : name.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    return '$sanitized.csv';
  }
}
