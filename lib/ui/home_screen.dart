import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../core/models.dart';
import '../data/project_repo.dart';
import '../data/repo_location_store.dart';
import 'flagged_materials_screen.dart';
import 'global_dynamic_components_screen.dart';
import 'global_parameters_screen.dart';
import 'project_screen.dart';
import 'standards_manager_screen.dart';
import 'widgets/bom_scaffold.dart';
import 'widgets/glass_container.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 5,
      child: BomScaffold(
        appBar: AppBar(
          toolbarHeight: 90,
          titleSpacing: 24,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  'BOM Toolkit',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'BOM Builder',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: _RepoLocationButton(),
            ),
            Padding(
              padding: EdgeInsets.only(right: 24),
              child: _GuideButton(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(82),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  color: Colors.white.withOpacity(0.04),
                ),
                child: TabBar(
                  splashBorderRadius: BorderRadius.circular(16),
                  indicatorPadding: const EdgeInsets.all(6),
                  labelPadding: const EdgeInsets.symmetric(vertical: 12),
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.8),
                        theme.colorScheme.secondary.withOpacity(0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.35),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  tabs: const [
                    Tab(text: 'Job'),
                    Tab(text: 'Standards'),
                    Tab(text: 'Dynamic Components'),
                    Tab(text: 'Parameters'),
                    Tab(text: 'Flagged Materials'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _JobTab(),
            StandardsManagerScreen(),
            GlobalDynamicComponentsScreen(),
            GlobalParametersScreen(),
            FlaggedMaterialsScreen(),
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
  final LocalProjectRepo _projectRepo = LocalProjectRepo();
  late Future<List<RecentProjectEntry>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _recentFuture = _projectRepo.listRecentProjects();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<RecentProjectEntry>>(
      future: _recentFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: GlassContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 42, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      'Load error',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snap.error.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final recentProjects = snap.data ?? const <RecentProjectEntry>[];
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: [
                      SizedBox(
                        width: isWide ? (constraints.maxWidth / 2) - 36 : double.infinity,
                        child: GlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: 'Project workspace',
                                subtitle:
                                    'Quickly spin up, resume, or revisit BOM projects from a streamlined console.',
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  _ActionTile(
                                    icon: Icons.play_circle_fill_rounded,
                                    title: 'New project',
                                    description: 'Start fresh with a guided setup for new work locations.',
                                    onTap: () async {
                                      final count = await _promptLocationCount(context);
                                      if (count != null && mounted) {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ProjectScreen(initialCount: count),
                                          ),
                                        );
                                        if (!mounted) return;
                                        setState(() {
                                          _recentFuture = _projectRepo.listRecentProjects();
                                        });
                                      }
                                    },
                                  ),
                                  _ActionTile(
                                    icon: Icons.folder_open_rounded,
                                    gradient: const [Color(0xFF7B61FF), Color(0xFF45C4FF)],
                                    title: 'Load project',
                                    description: 'Open an existing build, pick up exactly where you left off.',
                                    onTap: () {
                                      _loadProject();
                                    },
                                  ),
                                  _ActionTile(
                                    icon: Icons.archive_rounded,
                                    gradient: const [Color(0xFF19A186), Color(0xFF71EFA3)],
                                    title: 'Archived projects',
                                    description: 'Review previous work or restore completed project files.',
                                    onTap: () {
                                      _showArchivedProjects();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: isWide ? (constraints.maxWidth / 2) - 36 : double.infinity,
                        child: GlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: 'Recent projects',
                                subtitle:
                                    'Jump back into the latest active projects in one tap.',
                              ),
                              const SizedBox(height: 20),
                              if (recentProjects.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.white.withOpacity(0.03),
                                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.history,
                                          color: theme.colorScheme.secondary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'No recent projects yet. Save or open a project to pin it here.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: Colors.white70),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                ...recentProjects.map((entry) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: Colors.white.withOpacity(0.03),
                                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            gradient: LinearGradient(
                                              colors: [
                                                theme.colorScheme.primary.withOpacity(0.4),
                                                theme.colorScheme.secondary.withOpacity(0.6),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.folder_special_outlined,
                                            color: theme.colorScheme.secondary,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                entry.name,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Opened ${_formatRecentTimestamp(entry.lastAccessedAt)}',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(color: Colors.white70),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => _openRecentProject(entry.name),
                                          child: const Text('Open'),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  FilledButton.icon(
                                    onPressed: _loadProject,
                                    icon: const Icon(Icons.folder_open_rounded),
                                    label: const Text('Browse projects'),
                                  ),
                                  const SizedBox(width: 16),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showArchivedProjects(),
                                    icon: const Icon(Icons.archive_outlined),
                                    label: const Text('Archived'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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

  Future<void> _openExistingProject(Project proj) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectScreen(
          initialCount: 0,
          loaded: proj.locations,
          name: proj.name,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _recentFuture = _projectRepo.listRecentProjects();
    });
  }

  Future<void> _openRecentProject(String name) async {
    final proj = await _projectRepo.loadProject(name);
    if (proj == null || !mounted) return;
    await _openExistingProject(proj);
  }

  String _formatRecentTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    }
    final days = diff.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
}

class _RepoLocationButton extends StatefulWidget {
  const _RepoLocationButton();

  @override
  State<_RepoLocationButton> createState() => _RepoLocationButtonState();
}

class _RepoLocationButtonState extends State<_RepoLocationButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = Colors.white.withOpacity(0.85);
    return TextButton(
      onPressed: _busy ? null : _selectFolder,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white.withOpacity(0.05),
        foregroundColor: foregroundColor,
      ).copyWith(
        side: MaterialStateProperty.all(
          BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        overlayColor: MaterialStateProperty.all(
          theme.colorScheme.primary.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color?>(Colors.white),
              ),
            )
          else
            Icon(Icons.folder_open, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            _busy ? 'Updating…' : 'Change data folder',
            style: theme.textTheme.labelLarge?.copyWith(
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFolder() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final selection = await getDirectoryPath();
      if (selection == null) {
        return;
      }

      final Directory targetDir = Directory(selection);
      final Directory absoluteTarget = targetDir.absolute;
      await absoluteTarget.create(recursive: true);
      final selectedPath = absoluteTarget.path;
      final bomDataPath =
          Directory(p.normalize(p.join(selectedPath, 'bom_data'))).absolute.path;
      final bomDataDir = Directory(bomDataPath);

      final store = RepoLocationStore.instance;
      final currentRoot = await store.resolveRootPath();
      final normalizedCurrent = Directory(currentRoot).absolute.path;
      if (p.equals(normalizedCurrent, bomDataPath)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected folder is already in use.')),
        );
        return;
      }

      var migrated = false;
      final hasExistingBomData = await bomDataDir.exists();
      if (!hasExistingBomData) {
        final sourceDir = Directory(normalizedCurrent);
        if (await sourceDir.exists()) {
          await bomDataDir.create(recursive: true);
          await _copyDirectory(sourceDir, bomDataDir);
          migrated = true;
        }
      }

      await store.setPreferredRoot(bomDataPath);
      if (!mounted) return;
      final buffer = StringBuffer('Standards location updated. ');
      if (migrated) {
        buffer.write('Copied existing files to the selected folder. ');
      } else if (hasExistingBomData) {
        buffer.write(
            'Existing BOM data in the selected location was kept untouched. ');
      }
      buffer.write('Restart or reload the app to load data from the new path.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(buffer.toString())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update data folder: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity
        in source.list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: source.path);
      if (relative.isEmpty) {
        continue;
      }
      final newPath = p.join(destination.path, relative);
      if (entity is File) {
        await File(newPath).parent.create(recursive: true);
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      }
    }
  }
}

class _GuideButton extends StatelessWidget {
  const _GuideButton();

  void _showGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _GuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: () => _showGuide(context),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white.withOpacity(0.05),
        foregroundColor: Colors.white.withOpacity(0.85),
      ).copyWith(
        side: MaterialStateProperty.all(
          BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        overlayColor: MaterialStateProperty.all(
          theme.colorScheme.secondary.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, color: theme.colorScheme.secondary),
          const SizedBox(width: 8),
          Text(
            'Need a refresher? Open the guide.',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideDialog extends StatelessWidget {
  const _GuideDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        'Getting started with BOM Builder',
        style: theme.textTheme.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Use this quick guide to understand the flow for building a bill of materials.',
            ),
            SizedBox(height: 16),
            _GuideStep(
              icon: Icons.assignment,
              title: '1. Review the Job tab',
              description:
                  'Browse available standards and select the ones that match your project. '
                  'Use the search and filters to focus on what you need.',
            ),
            _GuideStep(
              icon: Icons.library_books,
              title: '2. Manage Standards',
              description:
                  'Open the Standards tab to explore, edit, and organize the templates your team relies on. '
                  'This is where you can fine-tune descriptions and assemblies.',
            ),
            _GuideStep(
              icon: Icons.extension,
              title: '3. Configure Dynamic Components',
              description:
                  'Customize reusable components so they match the unique needs of each project. '
                  'Adjust options and save them for the team to reuse.',
            ),
            _GuideStep(
              icon: Icons.tune,
              title: '4. Update Global Parameters',
              description:
                  'Set project-wide variables like Pole height, Wire size, or Span length. '
                  'These values feed into every BOM you build.',
            ),
            SizedBox(height: 12),
            Text(
              'Tip: Standards are your single source of truth—keep them accurate and everyone benefits.',
            ),
          ],
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

class _GuideStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _GuideStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<int?> _promptLocationCount(BuildContext context) async {
  final controller = TextEditingController(text: '1');
  return showDialog<int>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Number of work locations'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Locations',
          hintText: 'How many work locations are you setting up?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final n = int.tryParse(controller.text.trim());
            Navigator.pop(context, n);
          },
          child: const Text('Continue'),
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
    final theme = Theme.of(context);
    final archivedMode = widget.mode == _ProjectListMode.archived;
    final title = archivedMode ? 'Archived projects' : 'Select project';
    final tooltip = archivedMode ? 'Unarchive project' : 'Archive project';
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
                archivedMode ? 'No archived projects.' : 'No projects saved.',
                style: theme.textTheme.bodyMedium,
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
                    tileColor: Colors.white.withOpacity(0.04),
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
                    onTap: processing
                        ? null
                        : () => Navigator.of(context).pop(
                              _ProjectSelection(
                                name,
                                archived: archivedMode,
                              ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.72),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final List<Color>? gradient;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = gradient ??
        [
          theme.colorScheme.primary.withOpacity(0.9),
          theme.colorScheme.primary.withOpacity(0.6),
        ];

    return SizedBox(
      width: 260,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withOpacity(0.4),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.25),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, size: 24, color: Colors.white),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
