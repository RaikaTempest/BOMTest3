import 'dart:convert';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _initialStateSignature = '';

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
    _searchController.addListener(_onSearchChanged);
    _initRepo();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
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
        _initialStateSignature = _serializeState();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        repo = null;
        materials = [];
        _serverMaterials = [];
        _resetMaterialIds();
        _loading = false;
        _initialStateSignature = _serializeState();
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
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
  }

  String _serializeState() => jsonEncode({
        'materials': [for (final m in materials) m.toJson()],
      });

  bool get _hasUnsavedChanges => _serializeState() != _initialStateSignature;

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved flagged material edits. Leave without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return shouldLeave == true;
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
        final flaggedBy = material.flaggedBy?.trim() ?? '';

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
            flaggedBy: flaggedBy.isEmpty ? null : flaggedBy,
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
        _initialStateSignature = _serializeState();
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

  List<int> get _filteredMaterialIndices {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return List<int>.generate(materials.length, (index) => index);
    }
    final matches = <int>[];
    for (var i = 0; i < materials.length; i++) {
      final material = materials[i];
      final mm = material.mm.toLowerCase();
      final name = material.name.toLowerCase();
      if (mm.contains(query) || name.contains(query)) {
        matches.add(i);
      }
    }
    return matches;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
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
    final filteredIndices = _filteredMaterialIndices;
    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: BomScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _confirmDiscardChanges()) {
                if (mounted) {
                  Navigator.of(context).maybePop();
                }
              }
            },
          ),
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
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search flagged materials',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: _searchController.clear,
                                    icon: const Icon(Icons.clear),
                                  ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: materials.isEmpty
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
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : filteredIndices.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No flagged materials match your search.',
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                                    itemCount: filteredIndices.length,
                                    itemBuilder: (context, displayIndex) {
                                      final index = filteredIndices[displayIndex];
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
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 24, bottom: 32, right: 24),
                        child: Row(
                          children: [
                            FilledButton.icon(
                              onPressed: repo == null ? null : _addMaterial,
                              icon: const Icon(Icons.add),
                              label: const Text('Add flagged material'),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Total: ${materials.length}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: repo == null ? null : _addMaterial,
          icon: const Icon(Icons.add),
          label: const Text('Add material'),
        ),
      ),
    );
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
  late TextEditingController flaggedByController;
  late bool alternativeAvailable;
  DateTime? flaggedAt;

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
    flaggedByController =
        TextEditingController(text: widget.material.flaggedBy ?? '');
    alternativeAvailable = widget.material.alternativeAvailable;
    flaggedAt = widget.material.flaggedAt;
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
    _syncController(flaggedByController, widget.material.flaggedBy ?? '');
    if (alternativeAvailable != widget.material.alternativeAvailable) {
      alternativeAvailable = widget.material.alternativeAvailable;
    }
    flaggedAt = widget.material.flaggedAt;
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
    final mm = mmController.text;
    final name = nameController.text;
    final note = noteController.text;
    final altMm = alternativeMmController.text;
    final altName = alternativeNameController.text;
    final flaggedBy = flaggedByController.text;
    return FlaggedMaterial(
      mm: mm,
      name: name,
      alternativeAvailable: alternativeAvailable,
      alternativeMm:
          alternativeAvailable && altMm.trim().isNotEmpty ? altMm : null,
      alternativeName:
          alternativeAvailable && altName.trim().isNotEmpty ? altName : null,
      note: note.trim().isEmpty ? null : note,
      flaggedAt: flaggedAt,
      flaggedBy: flaggedBy.trim().isEmpty ? null : flaggedBy,
    );
  }

  void _notify() {
    widget.onChanged(_buildMaterial());
  }

  Future<void> _pickFlaggedAt() async {
    final context = this.context;
    final now = DateTime.now();
    final initialDate = flaggedAt ?? now;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initialDate,
    );
    if (date == null) return;

    final initialTime = flaggedAt != null
        ? TimeOfDay.fromDateTime(flaggedAt!)
        : TimeOfDay.fromDateTime(now);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    setState(() {
      if (time == null) {
        flaggedAt = DateTime(date.year, date.month, date.day);
      } else {
        flaggedAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      }
    });
    _notify();
  }

  void _clearFlaggedAt() {
    if (flaggedAt == null) return;
    setState(() {
      flaggedAt = null;
    });
    _notify();
  }

  String _formatFlaggedAt(BuildContext context) {
    final value = flaggedAt;
    if (value == null) {
      return 'Set flagged date & time';
    }
    final localizations = MaterialLocalizations.of(context);
    final dateText = localizations.formatMediumDate(value);
    final timeText = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ??
          false,
    );
    return '$dateText · $timeText';
  }

  @override
  void dispose() {
    mmController.dispose();
    nameController.dispose();
    noteController.dispose();
    alternativeMmController.dispose();
    alternativeNameController.dispose();
    flaggedByController.dispose();
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
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFlaggedAt,
                icon: const Icon(Icons.event_outlined),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatFlaggedAt(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.02),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: flaggedByController,
                decoration: const InputDecoration(labelText: 'Flagged by'),
                onChanged: (_) => _notify(),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Clear flagged date',
              child: IconButton(
                onPressed: flaggedAt == null ? null : _clearFlaggedAt,
                icon: const Icon(Icons.clear),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
