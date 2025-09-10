import 'package:flutter/material.dart';
import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';
import 'new_job_screen.dart';
import 'standards_manager_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BOM Builder'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Job'),
              Tab(text: 'Standards'),
              Tab(text: 'Approvals'),
              Tab(text: 'Aliases'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _JobTab(),
            StandardsManagerScreen(),
            Center(child: Text('Approvals')),
            Center(child: Text('Aliases')),
          ],
        ),
      ),
    );
  }
}

class _JobTab extends StatefulWidget {
  const _JobTab();

  @override
  State<_JobTab> createState() => _JobTabState();
}

class _JobTabState extends State<_JobTab> {
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
            RuleDef(expr: {'>=': [ {'var': 'PoleHeight'}, 40 ]}, outputs: [OutputSpec(mm: 'MM#PC-40', qty: 1)]),
            RuleDef(expr: {'<':  [ {'var': 'PoleHeight'}, 40 ]}, outputs: [OutputSpec(mm: 'MM#PC-35', qty: 1)]),
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Load error: ${snap.error}'));
        }
        final standards = snap.data ?? const <StandardDef>[];
        return NewJobScreen(standards: standards);
      },
    );
  }
}

