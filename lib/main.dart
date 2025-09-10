// lib/main.dart
import 'package:flutter/material.dart';
import 'core/models.dart';
import 'ui/new_job_screen.dart';
import 'data/repo_factory.dart';
import 'data/repo.dart';

void main() => runApp(const BomApp());

class BomApp extends StatelessWidget {
  const BomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Entrypoint(),
    );
  }
}

class Entrypoint extends StatefulWidget {
  const Entrypoint({super.key});
  @override
  State<Entrypoint> createState() => _EntrypointState();
}

class _EntrypointState extends State<Entrypoint> {
  late final StandardsRepo repo;
  Future<List<StandardDef>>? _future;

  @override
  void initState() {
    super.initState();
    repo = createRepo();
    _future = _loadOrSeed();
  }

  Future<List<StandardDef>> _loadOrSeed() async {
    var list = await repo.listStandards();
    if (list.isEmpty) {
      // Seed FS12 once on first run for the current platform backend.
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
      await repo.saveStandard(std);
      list = await repo.listStandards();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StandardDef>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Load error: ${snap.error}')),
          );
        }
        final standards = snap.data ?? const <StandardDef>[];
        return NewJobScreen(standards: standards);
      },
    );
  }
}
