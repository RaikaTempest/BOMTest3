import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';

class DebugRepoScreen extends StatefulWidget {
  const DebugRepoScreen({super.key});
  @override
  State<DebugRepoScreen> createState() => _DebugRepoScreenState();
}

class _DebugRepoScreenState extends State<DebugRepoScreen> {
  final StandardsRepo repo = createRepo();
  String location = kIsWeb ? 'web localStorage' : '(see below)';
  List<StandardDef> items = [];
  String dump = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Try to get a hint for Windows/macOS/Linux
    if (!kIsWeb) {
      location = 'App Documents/bom_data (platform-specific path)';
    }
    final list = await repo.listStandards();
    setState(() {
      items = list;
      dump = const JsonEncoder.withIndent('  ').convert(
        list.map((s) => s.toJson()).toList(),
      );
    });
  }

  Future<void> _resetSeed() async {
    // force overwrite FS12 with the known-good demo
    final std = StandardDef(
      code: 'FS12',
      name: 'Framing Standard 12',
      parameters: [ParameterDef(key: 'PoleHeight', type: ParamType.number)],
      staticComponents: [StaticComponent(mm: 'MM#BRACE-STD', qty: 2)],
      dynamicComponents: [
        DynamicComponentDef(name: 'Primary Connector', rules: [
          RuleDef(expr: {">=": [ {"var":"PoleHeight"}, 40 ]}, outputs: [OutputSpec(mm: "MM#PC-40", qty: 1)]),
          RuleDef(expr: {"<":  [ {"var":"PoleHeight"}, 40 ]}, outputs: [OutputSpec(mm: "MM#PC-35", qty: 1)]),
        ])
      ],
    );
    await repo.saveStandard(std);      // overwrite
    final list = await repo.listStandards();
    setState(() {
      items = list;
      dump = const JsonEncoder.withIndent('  ').convert(
        list.map((s) => s.toJson()).toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repo Debug')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backend: $location'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(onPressed: _load, child: const Text('Reload')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _resetSeed, child: const Text('Reset demo FS12')),
              ],
            ),
            const Divider(height: 24),
            const Text('Standards JSON dump (current backend):'),
            const SizedBox(height: 8),
            Expanded(
              child: SelectableText(
                dump.isEmpty ? '(empty)' : dump,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
