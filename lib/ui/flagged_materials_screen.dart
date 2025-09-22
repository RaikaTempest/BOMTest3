import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/repo.dart';
import '../data/repo_factory.dart';
import 'widgets/bom_scaffold.dart';
import 'widgets/glass_container.dart';

class FlaggedMaterialsScreen extends StatefulWidget {
  final Future<StandardsRepo> Function()? repoBuilder;

  const FlaggedMaterialsScreen({super.key, this.repoBuilder});

  @override
  State<FlaggedMaterialsScreen> createState() => _FlaggedMaterialsScreenState();
}

class _FlaggedMaterialsScreenState extends State<FlaggedMaterialsScreen> {
  StandardsRepo? repo;
  List<FlaggedMaterial> materials = [];
  List<FlaggedMaterial> _serverMaterials = [];
  final List<String> _materialIds = [];
  int _nextMaterialId = 0;
  bool _loading = true;

  String _createMaterialId() => 'flagged_material_${_nextMaterialId++}';

  void _resetMaterialIds() {
    _nextMaterialId = 0;
    _materialIds
      ..clear()
      ..addAll(List.generate(materials.length, (_) => _createMaterialId()));
  }

  @override
  void initState() {
    super.initState();
    _initRepo();
  }

  Future<void> _initRepo() async {
    try {
      final loader = widget.repoBuilder ?? createRepo;
      final loadedRepo = await loader();
      final list = await loadedRepo.loadFlaggedMaterials();
      if (!mounted) return;
      setState(() {
        repo = loadedRepo;
        materials = list;
        _serverMaterials = List<FlaggedMaterial>.from(list);
        _resetMaterialIds();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        repo = null;
        materials = [];
        _serverMaterials = [];
        _resetMaterialIds();
        _loading = false;
      });
    }
  }

  void _onMaterialChanged(int index, FlaggedMaterial material) {
    setState(() {
      materials[index] = material;
    });
  }

  void _removeMaterial(int index) {
    setState(() {
      materials.removeAt(index);
      _materialIds.removeAt(index);
    });
  }

  void _addMaterial() {
    setState(() {
      materials.add(const FlaggedMaterial(mm: '', name: ''));
      _materialIds.add(_createMaterialId());
    });
  }

  Future<void> _save() async {
    final repo = this.repo;
    if (repo == null) return;

    try {
      final cleaned = <FlaggedMaterial>[];
      final seen = <String>{};

      for (final material in materials) {
        final mm = material.mm.trim();
        final name = material.name.trim();
        final note = material.note?.trim() ?? '';
        final altMm = material.alternativeMm?.trim() ?? '';
        final altName = material.alternativeName?.trim() ?? '';

        if (mm.isEmpty && name.isEmpty && note.isEmpty) {
          continue;
        }
        if (mm.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Each entry must include an MM#.')),
          );
          return;
        }
        if (!seen.add(mm.toLowerCase())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Duplicate MM#: $mm')),
          );
          return;
        }

        cleaned.add(
          FlaggedMaterial(
            mm: mm,
            name: name,
            alternativeAvailable: material.alternativeAvailable,
            alternativeMm: material.alternativeAvailable && altMm.isNotEmpty
                ? altMm
                : null,
            alternativeName: material.alternativeAvailable && altName.isNotEmpty
                ? altName
                : null,
            note: note.isEmpty ? null : note,
            flaggedAt: material.flaggedAt,
            flaggedBy: material.flaggedBy,
          ),
        );
      }

      cleaned.sort((a, b) => a.mm.toLowerCase().compareTo(b.mm.toLowerCase()));
      final result = await repo.saveFlaggedMaterials(
        FlaggedMaterialsSaveRequest(
          original: _serverMaterials,
          updated: cleaned,
        ),
      );
      if (!mounted) return;

      _serverMaterials = List<FlaggedMaterial>.from(result.merged);

      if (!result.didSave) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Conflicts detected. Review the flagged materials list to continue.',
            ),
          ),
        );
        await _showConflictDialog(result);
        return;
      }

      setState(() {
        materials = result.merged;
        _resetMaterialIds();
      });

      if (result.hasRemoteChanges) {
        _showMergeSnackBar(result.remoteChanges);
      } else if (result.wroteFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flagged materials saved.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to save.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e')),
      );
    }
  }

  Future<void> _showConflictDialog(FlaggedMaterialsSaveResult result) async {
    if (!mounted) return;
    final shouldReload = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Conflicts detected'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Another session updated these materials. Resolve the conflicts below or reload the remote list.',
                ),
                const SizedBox(height: 12),
                for (final conflict in result.conflicts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(_describeConflict(conflict)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reload remote data'),
            ),
          ],
        );
      },
    );

    if (shouldReload == true && mounted) {
      setState(() {
        materials = List<FlaggedMaterial>.from(_serverMaterials);
        _resetMaterialIds();
      });
    }
  }

  void _showMergeSnackBar(Set<String> mmList) {
    final display = mmList.toList();
    display.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final preview = display.length > 3
        ? '${display.take(3).join(', ')} and ${display.length - 3} more'
        : display.join(', ');
    final message = display.isEmpty
        ? 'Flagged materials saved.'
        : 'Merged updates for: $preview';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: display.isEmpty
            ? null
            : SnackBarAction(
                label: 'Review',
                onPressed: () => _showMergeDetails(display),
              ),
      ),
    );
  }

  void _showMergeDetails(List<String> mmList) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Merged updates'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The following materials were updated with remote changes during the save:',
                ),
                const SizedBox(height: 12),
                for (final mm in mmList)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $mm'),
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
      },
    );
  }

  String _describeConflict(FlaggedMaterialConflict conflict) {
    final fields = conflict.fields.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final joinedFields = fields.isEmpty ? 'entry' : fields.join(', ');
    switch (conflict.type) {
      case FlaggedMaterialConflictType.addition:
        return '${conflict.mm}: Added in multiple places. Review the entry before saving.';
      case FlaggedMaterialConflictType.removal:
        return '${conflict.mm}: Removed remotely while edited locally.';
      case FlaggedMaterialConflictType.field:
        return '${conflict.mm}: Conflicting changes to $joinedFields.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = this.repo;
    final theme = Theme.of(context);
    return BomScaffold(
      appBar: AppBar(
        title: const Text('Flagged Materials'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: FilledButton.icon(
              onPressed: repo == null ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save changes'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : repo == null
              ? const Center(child: Text('Failed to load repository.'))
              : materials.isEmpty
                  ? Center(
                      child: GlassContainer(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              size: 46,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No flagged materials yet',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Track materials that should be avoided and specify approved alternatives when available.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                      itemCount: materials.length,
                      itemBuilder: (context, index) {
                        return GlassContainer(
                          key: ValueKey(_materialIds[index]),
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          child: _FlaggedMaterialEditor(
                            material: materials[index],
                            onChanged: (m) => _onMaterialChanged(index, m),
                            onDelete: () => _removeMaterial(index),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: repo == null ? null : _addMaterial,
        icon: const Icon(Icons.add),
        label: const Text('Add material'),
      ),
    );
  }
}

class _FlaggedMaterialEditor extends StatefulWidget {
  final FlaggedMaterial material;
  final ValueChanged<FlaggedMaterial> onChanged;
  final VoidCallback onDelete;

  const _FlaggedMaterialEditor({
    required this.material,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });

  @override
  State<_FlaggedMaterialEditor> createState() => _FlaggedMaterialEditorState();
}

class _FlaggedMaterialEditorState extends State<_FlaggedMaterialEditor> {
  late TextEditingController mmController;
  late TextEditingController nameController;
  late TextEditingController noteController;
  late TextEditingController alternativeMmController;
  late TextEditingController alternativeNameController;
  late bool alternativeAvailable;
  DateTime? flaggedAt;
  String? flaggedBy;

  @override
  void initState() {
    super.initState();
    mmController = TextEditingController(text: widget.material.mm);
    nameController = TextEditingController(text: widget.material.name);
    noteController = TextEditingController(text: widget.material.note ?? '');
    alternativeMmController =
        TextEditingController(text: widget.material.alternativeMm ?? '');
    alternativeNameController =
        TextEditingController(text: widget.material.alternativeName ?? '');
    alternativeAvailable = widget.material.alternativeAvailable;
    flaggedAt = widget.material.flaggedAt;
    flaggedBy = widget.material.flaggedBy;
  }

  @override
  void didUpdateWidget(covariant _FlaggedMaterialEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(mmController, widget.material.mm);
    _syncController(nameController, widget.material.name);
    _syncController(noteController, widget.material.note ?? '');
    _syncController(alternativeMmController, widget.material.alternativeMm ?? '');
    _syncController(
        alternativeNameController, widget.material.alternativeName ?? '');
    if (alternativeAvailable != widget.material.alternativeAvailable) {
      alternativeAvailable = widget.material.alternativeAvailable;
    }
    flaggedAt = widget.material.flaggedAt;
    flaggedBy = widget.material.flaggedBy;
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

  FlaggedMaterial _buildMaterial() {
    final mm = mmController.text.trim();
    final name = nameController.text.trim();
    final note = noteController.text.trim();
    final altMm = alternativeMmController.text.trim();
    final altName = alternativeNameController.text.trim();
    return FlaggedMaterial(
      mm: mm,
      name: name,
      alternativeAvailable: alternativeAvailable,
      alternativeMm: alternativeAvailable && altMm.isNotEmpty ? altMm : null,
      alternativeName:
          alternativeAvailable && altName.isNotEmpty ? altName : null,
      note: note.isEmpty ? null : note,
      flaggedAt: flaggedAt,
      flaggedBy: flaggedBy,
    );
  }

  void _notify() {
    widget.onChanged(_buildMaterial());
  }

  @override
  void dispose() {
    mmController.dispose();
    nameController.dispose();
    noteController.dispose();
    alternativeMmController.dispose();
    alternativeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showAlternative = alternativeAvailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: mmController,
                decoration: const InputDecoration(labelText: 'MM#'),
                onChanged: (_) => _notify(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Material name'),
                onChanged: (_) => _notify(),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Remove material',
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
        TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Notes / reason'),
          maxLines: null,
          onChanged: (_) => _notify(),
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
              Switch(
                value: alternativeAvailable,
                onChanged: (value) {
                  setState(() {
                    alternativeAvailable = value;
                  });
                  _notify();
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Alternative available',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (showAlternative) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: alternativeMmController,
                  decoration:
                      const InputDecoration(labelText: 'Alternative MM#'),
                  onChanged: (_) => _notify(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: alternativeNameController,
                  decoration:
                      const InputDecoration(labelText: 'Alternative name'),
                  onChanged: (_) => _notify(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
