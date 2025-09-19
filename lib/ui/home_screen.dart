import 'package:flutter/material.dart';
import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';
import 'project_screen.dart';
import 'standards_manager_screen.dart';
import 'global_parameters_screen.dart';
import '../data/project_repo.dart';

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
              Tab(text: 'Parameters'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _JobTab(),
            const StandardsManagerScreen(),
            const Center(child: Text('Approvals')),
            const GlobalParametersScreen(),
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
          DynamicComponentDef(
            name: 'Primary Connector',
            rules: [
              RuleDef(
                expr: {
                  '>=': [
                    {'var': 'PoleHeight'},
                    40,
                  ],
                },
                outputs: [OutputSpec(mm: 'MM#PC-40', qty: 1)],
              ),
              RuleDef(
                expr: {
                  '<': [
                    {'var': 'PoleHeight'},
                    40,
                  ],
                },
                outputs: [OutputSpec(mm: 'MM#PC-35', qty: 1)],
              ),
            ],
          ),
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
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final count = await _promptLocationCount(context);
                  if (count != null) {
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProjectScreen(initialCount: count),
                      ),
                    );
                  }
                },
                child: const Text('New project'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProject,
                child: const Text('Load project'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showArchivedProjects,
                child: const Text('Archived projects'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadProject() async {
    final repo = LocalProjectRepo();
    final selection = await showDialog<_ProjectSelection>(
      context: context,
      builder: (_) => _ProjectListDialog(
        repo: repo,
        mode: _ProjectListMode.active,
      ),
    );
    if (selection == null) return;
    final proj = await repo.loadProject(
      selection.name,
      archived: selection.archived,
    );
    if (proj == null || !mounted) return;
    _openExistingProject(proj);
  }

  Future<void> _showArchivedProjects() async {
    final repo = LocalProjectRepo();
    final selection = await showDialog<_ProjectSelection>(
      context: context,
      builder: (_) => _ProjectListDialog(
        repo: repo,
        mode: _ProjectListMode.archived,
      ),
    );
    if (selection == null) return;
    final proj = await repo.loadProject(
      selection.name,
      archived: selection.archived,
    );
    if (proj == null || !mounted) return;
    _openExistingProject(proj);
  }

  void _openExistingProject(Project proj) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectScreen(
          initialCount: 0,
          loaded: proj.locations,
          name: proj.name,
        ),
      ),
    );
  }
}

Future<int?> _promptLocationCount(BuildContext context) async {
  final controller = TextEditingController(text: '1');
  return showDialog<int>(
    context: context,
    builder:
        (_) => AlertDialog(
          title: const Text('Number of work locations'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final n = int.tryParse(controller.text.trim());
                Navigator.pop(context, n); // may be null
              },
              child: const Text('OK'),
            ),
          ],
        ),
  );
}

enum _ProjectListMode { active, archived }

class _ProjectSelection {
  final String name;
  final bool archived;

  const _ProjectSelection(this.name, {required this.archived});
}

class _ProjectListDialog extends StatefulWidget {
  final LocalProjectRepo repo;
  final _ProjectListMode mode;

  const _ProjectListDialog({
    required this.repo,
    required this.mode,
  });

  @override
  State<_ProjectListDialog> createState() => _ProjectListDialogState();
}

class _ProjectListDialogState extends State<_ProjectListDialog> {
  late Future<List<String>> _future;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<String>> _load() {
    return widget.repo.listProjects(
      archived: widget.mode == _ProjectListMode.archived,
    );
  }

  Future<void> _toggleArchive(String name) async {
    setState(() {
      _processing.add(name);
    });
    try {
      if (widget.mode == _ProjectListMode.archived) {
        await widget.repo.unarchiveProject(name);
      } else {
        await widget.repo.archiveProject(name);
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _processing.remove(name);
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final archivedMode = widget.mode == _ProjectListMode.archived;
    final title = archivedMode ? 'Archived projects' : 'Select project';
    final tooltip =
        archivedMode ? 'Unarchive project' : 'Archive project';
    final icon = archivedMode ? Icons.unarchive : Icons.archive;

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<String>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final names = snapshot.data ?? <String>[];
            if (names.isEmpty) {
              return Text(
                archivedMode
                    ? 'No archived projects.'
                    : 'No projects saved.',
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: names.length,
                itemBuilder: (context, index) {
                  final name = names[index];
                  final processing = _processing.contains(name);
                  return ListTile(
                    title: Text(name),
                    onTap: processing
                        ? null
                        : () => Navigator.of(context).pop(
                              _ProjectSelection(
                                name,
                                archived: archivedMode,
                              ),
                            ),
                    trailing: processing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: Icon(icon),
                            tooltip: tooltip,
                            onPressed: () => _toggleArchive(name),
                          ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
