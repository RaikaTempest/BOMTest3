import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';
import 'widgets/parameter_editor.dart';

class GlobalParametersScreen extends StatefulWidget {
  const GlobalParametersScreen({super.key});

  @override
  State<GlobalParametersScreen> createState() => _GlobalParametersScreenState();
}

class _GlobalParametersScreenState extends State<GlobalParametersScreen> {
  late final StandardsRepo repo;
  List<ParameterDef> parameters = [];
  final List<String> _parameterIds = [];
  int _nextParameterId = 0;
  bool _loading = true;

  String _createParameterId() => 'global_param_${_nextParameterId++}';

  void _resetParameterIds() {
    _nextParameterId = 0;
    _parameterIds
      ..clear()
      ..addAll(List.generate(parameters.length, (_) => _createParameterId()));
  }

  @override
  void initState() {
    super.initState();
    repo = createRepo();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await repo.loadGlobalParameters();
      setState(() {
        parameters = list;
        _resetParameterIds();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        parameters = [];
        _resetParameterIds();
        _loading = false;
      });
    }
  }

  void _onParameterChanged(int index, ParameterDef def) {
    setState(() {
      parameters[index] = def;
    });
  }

  void _removeParameter(int index) {
    setState(() {
      parameters.removeAt(index);
      _parameterIds.removeAt(index);
    });
  }

  void _addParameter() {
    setState(() {
      parameters.add(ParameterDef(key: '', type: ParamType.text));
      _parameterIds.add(_createParameterId());
    });
  }

  Future<void> _save() async {
    try {
      final cleaned = <ParameterDef>[];
      final seen = <String>{};
      for (final p in parameters) {
        final key = p.key.trim();
        if (key.isEmpty) {
          continue;
        }
        if (!seen.add(key)) {
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
      cleaned.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
      await repo.saveGlobalParameters(cleaned);
      setState(() {
        parameters = List<ParameterDef>.from(cleaned);
        _resetParameterIds();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parameters saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Parameters'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : parameters.isEmpty
              ? const Center(child: Text('No parameters defined yet.'))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: ListView(
                    children: [
                      ...parameters
                          .asMap()
                          .entries
                          .map(
                            (e) => ParameterEditor(
                              key: ValueKey(_parameterIds[e.key]),
                              def: e.value,
                              onChanged: (p) => _onParameterChanged(e.key, p),
                              onDelete: () => _removeParameter(e.key),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addParameter,
        child: const Icon(Icons.add),
      ),
    );
  }
}
