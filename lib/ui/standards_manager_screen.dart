import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';

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
  late final TextEditingController params;
  late final TextEditingController statics;
  late final TextEditingController dynamics;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    code = TextEditingController(text: e?.code ?? '');
    name = TextEditingController(text: e?.name ?? '');
    params = TextEditingController(
      text: e == null
          ? '[]'
          : jsonEncode(e.parameters.map((p) => p.toJson()).toList()),
    );
    statics = TextEditingController(
      text: e == null
          ? '[]'
          : jsonEncode(e.staticComponents.map((c) => c.toJson()).toList()),
    );
    dynamics = TextEditingController(
      text: e == null
          ? '[]'
          : jsonEncode(e.dynamicComponents.map((d) => d.toJson()).toList()),
    );
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    params.dispose();
    statics.dispose();
    dynamics.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final std = StandardDef(
        code: code.text.trim(),
        name: name.text.trim(),
        parameters: (jsonDecode(params.text) as List)
            .map((e) => ParameterDef.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        staticComponents: (jsonDecode(statics.text) as List)
            .map((e) => StaticComponent.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        dynamicComponents: (jsonDecode(dynamics.text) as List)
            .map(
                (e) => DynamicComponentDef.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
      await widget.repo.saveStandard(std);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save error: $e')));
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
            child: const Text('Save', style: TextStyle(color: Colors.white)),
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
            TextField(
              controller: params,
              decoration: const InputDecoration(labelText: 'Parameters (JSON)'),
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: statics,
              decoration:
                  const InputDecoration(labelText: 'Static Components (JSON)'),
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dynamics,
              decoration:
                  const InputDecoration(labelText: 'Dynamic Components (JSON)'),
              maxLines: 6,
            ),
          ],
        ),
      ),
    );
  }
}

