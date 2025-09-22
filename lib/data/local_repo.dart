// lib/data/local_repo.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/models.dart';
import 'repo.dart';
import 'repo_location_store.dart';

class LocalStandardsRepo implements StandardsRepo {
  LocalStandardsRepo({
    String? overrideRootPath,
    RepoLocationStore? locationStore,
  })  : _locationStore = locationStore ?? RepoLocationStore.instance,
        _overridePath = overrideRootPath {
    _locationStore.changes.listen((path) {
      _overridePath = path;
      if (_currentPath != path) {
        _currentPath = null;
        _root = null;
      }
    });
  }

  final RepoLocationStore _locationStore;
  Directory? _root;
  String? _overridePath;
  String? _currentPath;

  Future<String> _resolveActiveRootPath() async {
    final override = _overridePath;
    if (override != null && override.trim().isNotEmpty) {
      return override;
    }
    final stored = await _locationStore.loadPreferredRoot();
    if (stored != null && stored.trim().isNotEmpty) {
      _overridePath = stored;
      return stored;
    }
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/bom_data';
  }

  Future<void> _bootstrapRoot(Directory root) async {
    await root.create(recursive: true);
    for (final sub in ['standards', 'cache/pending', 'cache/approved']) {
      await Directory('${root.path}/$sub').create(recursive: true);
    }
    final parametersFile = File('${root.path}/parameters.json');
    if (!await parametersFile.exists()) {
      await parametersFile.writeAsString(jsonEncode(<dynamic>[]), flush: true);
    }
    final dynamicComponentsFile = File('${root.path}/dynamic_components.json');
    if (!await dynamicComponentsFile.exists()) {
      await dynamicComponentsFile.writeAsString(jsonEncode(<dynamic>[]), flush: true);
    }
    final flaggedMaterialsFile = File('${root.path}/flagged_materials.json');
    if (!await flaggedMaterialsFile.exists()) {
      await flaggedMaterialsFile.writeAsString(
        jsonEncode(<dynamic>[]),
        flush: true,
      );
    }
  }

  Future<Directory> _ensureRoot() async {
    final path = await _resolveActiveRootPath();
    if (_root != null && _currentPath == path) {
      return _root!;
    }
    final root = Directory(path);
    await _bootstrapRoot(root);
    _root = root;
    _currentPath = path;
    return root;
  }

  Future<File> _stdFile(String code) async {
    final r = await _ensureRoot();
    return File('${r.path}/standards/$code.json');
  }

  Future<File> _parametersFile() async {
    final r = await _ensureRoot();
    return File('${r.path}/parameters.json');
  }

  Future<File> _dynamicComponentsFile() async {
    final r = await _ensureRoot();
    return File('${r.path}/dynamic_components.json');
  }

  Future<File> _flaggedMaterialsFile() async {
    final r = await _ensureRoot();
    return File('${r.path}/flagged_materials.json');
  }

  Future<File> _pendingFile(String key) async {
    final r = await _ensureRoot();
    return File('${r.path}/cache/pending/$key.json');
  }

  Future<File> _approvedFile(String key) async {
    final r = await _ensureRoot();
    return File('${r.path}/cache/approved/$key.json');
  }

  Future<T> _withFileLock<T>(File file, Future<T> Function() action) async {
    final lockFile = File('${file.path}.lock');
    RandomAccessFile? raf;
    try {
      raf = await lockFile.open(mode: FileMode.write);
      await raf.lock(FileLock.blockingExclusive);
      return await action();
    } finally {
      if (raf != null) {
        try {
          await raf.unlock();
        } catch (_) {}
        await raf.close();
      }
    }
  }

  @override
  Future<List<StandardDef>> listStandards() async {
    final r = await _ensureRoot();
    final dir = Directory('${r.path}/standards');
    if (!await dir.exists()) return [];
    final out = <StandardDef>[];
    await for (final f in dir.list()) {
      if (f is File && f.path.endsWith('.json')) {
        final txt = await f.readAsString();
        final j = jsonDecode(txt) as Map<String, dynamic>;
        out.add(StandardDef.fromJson(j));
      }
    }
    out.sort((a, b) => a.code.compareTo(b.code));
    return out;
  }

  @override
  Future<void> saveStandard(StandardDef std) async {
    final f = await _stdFile(std.code);
    await _withFileLock(f, () async {
      if (await f.exists()) {
        await f.readAsString();
      }
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(std.toJson()), flush: true);
      await tmp.rename(f.path);
    });
  }

  @override
  Future<void> deleteStandard(String code) async {
    final f = await _stdFile(code);
    await _withFileLock(f, () async {
      if (await f.exists()) {
        await f.readAsString();
        await f.delete();
      }
    });
  }

  @override
  Future<List<ParameterDef>> loadGlobalParameters() async {
    final f = await _parametersFile();
    final txt = await f.readAsString();
    if (txt.trim().isEmpty) return [];
    final j = jsonDecode(txt);
    if (j is List) {
      return j
          .whereType<Map>()
          .map((e) => ParameterDef.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  @override
  Future<void> saveGlobalParameters(List<ParameterDef> parameters) async {
    final f = await _parametersFile();
    await _withFileLock(f, () async {
      if (await f.exists()) {
        await f.readAsString();
      }
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(
        jsonEncode(parameters.map((e) => e.toJson()).toList()),
        flush: true,
      );
      await tmp.rename(f.path);
    });
  }

  @override
  Future<List<DynamicComponentDef>> loadGlobalDynamicComponents() async {
    final f = await _dynamicComponentsFile();
    final txt = await f.readAsString();
    if (txt.trim().isEmpty) return [];
    final j = jsonDecode(txt);
    if (j is List) {
      return j
          .whereType<Map>()
          .map(
            (e) =>
                DynamicComponentDef.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    }
    return [];
  }

  @override
  Future<void> saveGlobalDynamicComponents(
      List<DynamicComponentDef> components) async {
    final f = await _dynamicComponentsFile();
    await _withFileLock(f, () async {
      if (await f.exists()) {
        await f.readAsString();
      }
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(
        jsonEncode(components.map((e) => e.toJson()).toList()),
        flush: true,
      );
      await tmp.rename(f.path);
    });
  }

  @override
  Future<List<FlaggedMaterial>> loadFlaggedMaterials() async {
    final f = await _flaggedMaterialsFile();
    final txt = await f.readAsString();
    if (txt.trim().isEmpty) return [];
    final j = jsonDecode(txt);
    if (j is List) {
      return j
          .whereType<Map>()
          .map((e) => FlaggedMaterial.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  @override
  Future<FlaggedMaterialsSaveResult> saveFlaggedMaterials(
      FlaggedMaterialsSaveRequest request) async {
    final f = await _flaggedMaterialsFile();
    return _withFileLock(f, () async {
      final existing = <FlaggedMaterial>[];
      if (await f.exists()) {
        final txt = await f.readAsString();
        if (txt.trim().isNotEmpty) {
          final decoded = jsonDecode(txt);
          if (decoded is List) {
            for (final entry in decoded) {
              if (entry is Map) {
                existing.add(
                  FlaggedMaterial.fromJson(entry.cast<String, dynamic>()),
                );
              }
            }
          }
        }
      }

      final plan = LocalStandardsRepo.planFlaggedMaterialsMerge(
        original: request.original,
        updated: request.updated,
        remote: existing,
      );

      var wroteFile = false;
      if (plan.conflicts.isEmpty && plan.needsWrite) {
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(
          jsonEncode(plan.merged.map((e) => e.toJson()).toList()),
          flush: true,
        );
        await tmp.rename(f.path);
        wroteFile = true;
      }

      return FlaggedMaterialsSaveResult(
        merged: plan.merged,
        conflicts: plan.conflicts,
        remoteChanges: plan.remoteChanges,
        wroteFile: wroteFile,
      );
    });
  }

  @override
  Future<void> saveCacheEntry(String key, Map<String, dynamic> entryJson) async {
    final f = await _pendingFile(key);
    await _withFileLock(f, () async {
      if (await f.exists()) {
        await f.readAsString();
      }
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(entryJson), flush: true);
      await tmp.rename(f.path);
    });
  }

  @override
  Future<Map<String, dynamic>?> getCacheEntry(String key) async {
    final f1 = await _pendingFile(key);
    if (await f1.exists()) {
      return jsonDecode(await f1.readAsString()) as Map<String, dynamic>;
    }
    final f2 = await _approvedFile(key);
    if (await f2.exists()) {
      return jsonDecode(await f2.readAsString()) as Map<String, dynamic>;
    }
    return null;
  }

  @override
  Future<Map<String, Map<String, dynamic>>> listPendingCache() async {
    final r = await _ensureRoot();
    final dir = Directory('${r.path}/cache/pending');
    final out = <String, Map<String, dynamic>>{};
    await for (final f in dir.list()) {
      if (f is File && f.path.endsWith('.json')) {
        final key = f.uri.pathSegments.last.replaceFirst('.json', '');
        out[key] = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      }
    }
    return out;
  }

  @override
  Future<void> approveCache(String key) async {
    final src = await _pendingFile(key);
    await _withFileLock(src, () async {
      if (!await src.exists()) return;
      final contents = await src.readAsString();
      final dst = await _approvedFile(key);
      await _withFileLock(dst, () async {
        if (await dst.exists()) {
          await dst.readAsString();
        }
        final tmp = File('${dst.path}.tmp');
        await tmp.writeAsString(contents, flush: true);
        await tmp.rename(dst.path);
      });
      await src.delete();
    });
  }

  @override
  Future<void> rejectCache(String key) async {
    final f = await _pendingFile(key);
    await _withFileLock(f, () async {
      if (await f.exists()) {
        await f.readAsString();
        await f.delete();
      }
    });
  }

  @visibleForTesting
  static FlaggedMaterialsMergePlan planFlaggedMaterialsMerge({
    required List<FlaggedMaterial> original,
    required List<FlaggedMaterial> updated,
    required List<FlaggedMaterial> remote,
  }) {
    final originalMap = _materialMap(original);
    final localMap = _materialMap(updated);
    final remoteMap = _materialMap(remote);

    final mergedMap = <String, FlaggedMaterial>{};
    final conflicts = <FlaggedMaterialConflict>[];
    final allKeys = <String>{}
      ..addAll(originalMap.keys)
      ..addAll(localMap.keys)
      ..addAll(remoteMap.keys);

    for (final key in allKeys) {
      final orig = originalMap[key];
      final local = localMap[key];
      final remoteEntry = remoteMap[key];

      if (orig == null) {
        if (local != null && remoteEntry != null) {
          if (_materialsEqual(local, remoteEntry)) {
            mergedMap[key] = remoteEntry;
          } else {
            conflicts.add(
              FlaggedMaterialConflict(
                mm: local.mm.isNotEmpty ? local.mm : remoteEntry.mm,
                type: FlaggedMaterialConflictType.addition,
                fields: const {'entry'},
                original: orig,
                local: local,
                remote: remoteEntry,
              ),
            );
          }
        } else if (local != null) {
          mergedMap[key] = local;
        } else if (remoteEntry != null) {
          mergedMap[key] = remoteEntry;
        }
        continue;
      }

      if (local == null && remoteEntry == null) {
        continue;
      }

      if (local == null) {
        if (remoteEntry == null) {
          continue;
        }
        if (_materialsEqual(remoteEntry, orig)) {
          continue;
        }
        conflicts.add(
          FlaggedMaterialConflict(
            mm: orig.mm,
            type: FlaggedMaterialConflictType.removal,
            fields: const {'entry'},
            original: orig,
            local: local,
            remote: remoteEntry,
          ),
        );
        continue;
      }

      if (remoteEntry == null) {
        if (_materialsEqual(local, orig)) {
          continue;
        }
        conflicts.add(
          FlaggedMaterialConflict(
            mm: local.mm.isNotEmpty ? local.mm : orig.mm,
            type: FlaggedMaterialConflictType.removal,
            fields: const {'entry'},
            original: orig,
            local: local,
            remote: remoteEntry,
          ),
        );
        continue;
      }

      final localChanged = _changedFields(orig, local);
      final remoteChanged = _changedFields(orig, remoteEntry);

      if (localChanged.isEmpty && remoteChanged.isEmpty) {
        mergedMap[key] = remoteEntry;
        continue;
      }

      if (remoteChanged.isEmpty) {
        mergedMap[key] = local;
        continue;
      }

      if (localChanged.isEmpty) {
        mergedMap[key] = remoteEntry;
        continue;
      }

      final intersection = localChanged.intersection(remoteChanged);
      if (intersection.isNotEmpty) {
        conflicts.add(
          FlaggedMaterialConflict(
            mm: local.mm.isNotEmpty ? local.mm : remoteEntry.mm,
            type: FlaggedMaterialConflictType.field,
            fields: intersection,
            original: orig,
            local: local,
            remote: remoteEntry,
          ),
        );
        continue;
      }

      mergedMap[key] = _mergeEntries(remoteEntry, local, localChanged);
    }

    if (conflicts.isNotEmpty) {
      final remoteSorted = _sortedMaterials(remote);
      final remoteChanges = _detectRemoteChanges(
        finalMap: remoteMap,
        localMap: localMap,
        originalMap: originalMap,
      );
      return FlaggedMaterialsMergePlan(
        merged: remoteSorted,
        conflicts: conflicts,
        remoteChanges: remoteChanges,
        needsWrite: false,
      );
    }

    final mergedList = _sortedMaterials(mergedMap.values.toList());
    final remoteSorted = _sortedMaterials(remote);
    final needsWrite = !_listsEqual(mergedList, remoteSorted);
    final remoteChanges = _detectRemoteChanges(
      finalMap: mergedMap,
      localMap: localMap,
      originalMap: originalMap,
    );

    return FlaggedMaterialsMergePlan(
      merged: mergedList,
      conflicts: const [],
      remoteChanges: remoteChanges,
      needsWrite: needsWrite,
    );
  }
}

class FlaggedMaterialsMergePlan {
  final List<FlaggedMaterial> merged;
  final List<FlaggedMaterialConflict> conflicts;
  final Set<String> remoteChanges;
  final bool needsWrite;

  const FlaggedMaterialsMergePlan({
    required this.merged,
    required this.conflicts,
    required this.remoteChanges,
    required this.needsWrite,
  });
}

const _flaggedMaterialFields = <String>{
  'mm',
  'name',
  'alternativeAvailable',
  'alternativeMm',
  'alternativeName',
  'note',
  'flaggedAt',
  'flaggedBy',
};

String _normalizeMm(String mm) => mm.trim().toLowerCase();

Map<String, FlaggedMaterial> _materialMap(List<FlaggedMaterial> list) {
  final map = <String, FlaggedMaterial>{};
  for (final material in list) {
    map[_normalizeMm(material.mm)] = material;
  }
  return map;
}

FlaggedMaterial _mergeEntries(
  FlaggedMaterial remote,
  FlaggedMaterial local,
  Set<String> localChanged,
) {
  return FlaggedMaterial(
    mm: localChanged.contains('mm') ? local.mm : remote.mm,
    name: localChanged.contains('name') ? local.name : remote.name,
    alternativeAvailable: localChanged.contains('alternativeAvailable')
        ? local.alternativeAvailable
        : remote.alternativeAvailable,
    alternativeMm: localChanged.contains('alternativeMm')
        ? local.alternativeMm
        : remote.alternativeMm,
    alternativeName: localChanged.contains('alternativeName')
        ? local.alternativeName
        : remote.alternativeName,
    note: localChanged.contains('note') ? local.note : remote.note,
    flaggedAt:
        localChanged.contains('flaggedAt') ? local.flaggedAt : remote.flaggedAt,
    flaggedBy:
        localChanged.contains('flaggedBy') ? local.flaggedBy : remote.flaggedBy,
  );
}

Set<String> _changedFields(FlaggedMaterial? base, FlaggedMaterial? other) {
  if (base == null || other == null) {
    return {..._flaggedMaterialFields};
  }
  final changed = <String>{};
  for (final field in _flaggedMaterialFields) {
    final a = _fieldValue(base, field);
    final b = _fieldValue(other, field);
    if (!_valueEquals(a, b)) {
      changed.add(field);
    }
  }
  return changed;
}

dynamic _fieldValue(FlaggedMaterial? material, String field) {
  if (material == null) return null;
  switch (field) {
    case 'mm':
      return material.mm;
    case 'name':
      return material.name;
    case 'alternativeAvailable':
      return material.alternativeAvailable;
    case 'alternativeMm':
      return material.alternativeMm;
    case 'alternativeName':
      return material.alternativeName;
    case 'note':
      return material.note;
    case 'flaggedAt':
      return material.flaggedAt;
    case 'flaggedBy':
      return material.flaggedBy;
  }
  return null;
}

bool _valueEquals(dynamic a, dynamic b) {
  if (a is DateTime && b is DateTime) {
    return a.isAtSameMomentAs(b);
  }
  return a == b;
}

bool _materialsEqual(FlaggedMaterial? a, FlaggedMaterial? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == null && b == null;
  for (final field in _flaggedMaterialFields) {
    if (!_valueEquals(_fieldValue(a, field), _fieldValue(b, field))) {
      return false;
    }
  }
  return true;
}

List<FlaggedMaterial> _sortedMaterials(List<FlaggedMaterial> list) {
  final copy = List<FlaggedMaterial>.from(list);
  copy.sort(
    (a, b) => _normalizeMm(a.mm).compareTo(_normalizeMm(b.mm)),
  );
  return copy;
}

bool _listsEqual(List<FlaggedMaterial> a, List<FlaggedMaterial> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_materialsEqual(a[i], b[i])) {
      return false;
    }
  }
  return true;
}

Set<String> _detectRemoteChanges({
  required Map<String, FlaggedMaterial> finalMap,
  required Map<String, FlaggedMaterial> localMap,
  required Map<String, FlaggedMaterial> originalMap,
}) {
  final keys = <String>{}
    ..addAll(finalMap.keys)
    ..addAll(localMap.keys);
  final changed = <String>{};
  for (final key in keys) {
    final finalEntry = finalMap[key];
    final localEntry = localMap[key];
    if (!_materialsEqual(finalEntry, localEntry)) {
      final label = finalEntry?.mm ??
          localEntry?.mm ??
          originalMap[key]?.mm ??
          key;
      changed.add(label);
    }
  }
  return changed;
}
