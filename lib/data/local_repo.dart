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

  Future<StandardDef?> _readStandardIfExists(File file) async {
    if (!await file.exists()) return null;
    final txt = await file.readAsString();
    if (txt.trim().isEmpty) return null;
    final decoded = jsonDecode(txt);
    if (decoded is Map<String, dynamic>) {
      return StandardDef.fromJson(decoded);
    }
    return null;
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
  Future<StandardSaveResult> saveStandard(StandardSaveRequest request) async {
    final updated = request.updated;
    final f = await _stdFile(updated.code);
    return _withFileLock(f, () async {
      final remote = await _readStandardIfExists(f);
      final plan = LocalStandardsRepo.planStandardMerge(
        original: request.original,
        updated: updated,
        remote: remote,
      );

      var wroteFile = false;
      if (plan.conflict == null && plan.needsWrite && plan.finalStandard != null) {
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(
          jsonEncode(plan.finalStandard!.toJson()),
          flush: true,
        );
        await tmp.rename(f.path);
        wroteFile = true;
      }

      return StandardSaveResult(
        merged: plan.finalStandard,
        conflict: plan.conflict,
        wroteFile: wroteFile,
        alreadyUpToDate: plan.conflict == null && !plan.needsWrite
            ? plan.alreadyUpToDate
            : false,
      );
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
  Future<ParametersSaveResult> saveGlobalParameters(
      ParametersSaveRequest request) async {
    final f = await _parametersFile();
    return _withFileLock(f, () async {
      final existing = <ParameterDef>[];
      if (await f.exists()) {
        final txt = await f.readAsString();
        if (txt.trim().isNotEmpty) {
          final decoded = jsonDecode(txt);
          if (decoded is List) {
            for (final entry in decoded) {
              if (entry is Map) {
                existing.add(
                  ParameterDef.fromJson(entry.cast<String, dynamic>()),
                );
              }
            }
          }
        }
      }

      final plan = LocalStandardsRepo.planParametersMerge(
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

      return ParametersSaveResult(
        merged: plan.merged,
        conflicts: plan.conflicts,
        remoteChanges: plan.remoteChanges,
        wroteFile: wroteFile,
      );
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
  Future<DynamicComponentsSaveResult> saveGlobalDynamicComponents(
      DynamicComponentsSaveRequest request) async {
    final f = await _dynamicComponentsFile();
    return _withFileLock(f, () async {
      final existing = <DynamicComponentDef>[];
      if (await f.exists()) {
        final txt = await f.readAsString();
        if (txt.trim().isNotEmpty) {
          final decoded = jsonDecode(txt);
          if (decoded is List) {
            for (final entry in decoded) {
              if (entry is Map) {
                existing.add(
                  DynamicComponentDef.fromJson(
                    entry.cast<String, dynamic>(),
                  ),
                );
              }
            }
          }
        }
      }

      final plan = LocalStandardsRepo.planDynamicComponentsMerge(
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

      return DynamicComponentsSaveResult(
        merged: plan.merged,
        conflicts: plan.conflicts,
        remoteChanges: plan.remoteChanges,
        wroteFile: wroteFile,
      );
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
  Future<CacheSaveResult> saveCacheEntry(CacheSaveRequest request) async {
    final f = await _pendingFile(request.key);
    return _withFileLock(f, () async {
      Map<String, dynamic>? remote;
      if (await f.exists()) {
        final txt = await f.readAsString();
        if (txt.trim().isNotEmpty) {
          final decoded = jsonDecode(txt);
          if (decoded is Map) {
            remote = decoded.cast<String, dynamic>();
          }
        }
      }

      final original = request.original;
      final updated = request.updated;
      CacheConflict? conflict;
      Map<String, dynamic>? finalEntry;
      var needsWrite = false;
      var alreadyUpToDate = false;

      if (original == null) {
        if (remote == null) {
          finalEntry = Map<String, dynamic>.from(updated);
          needsWrite = true;
        } else if (_mapsDeepEqual(remote, updated)) {
          finalEntry = remote;
          alreadyUpToDate = true;
        } else {
          conflict = CacheConflict(
            key: request.key,
            type: CacheConflictType.alreadyExists,
            original: null,
            local: Map<String, dynamic>.from(updated),
            remote: remote,
          );
          finalEntry = remote;
        }
      } else {
        if (remote == null) {
          conflict = CacheConflict(
            key: request.key,
            type: CacheConflictType.deletedRemotely,
            original: Map<String, dynamic>.from(original),
            local: Map<String, dynamic>.from(updated),
            remote: null,
          );
        } else if (_mapsDeepEqual(remote, original)) {
          if (_mapsDeepEqual(updated, original)) {
            finalEntry = remote;
            alreadyUpToDate = true;
          } else {
            finalEntry = Map<String, dynamic>.from(updated);
            needsWrite = true;
          }
        } else if (_mapsDeepEqual(remote, updated)) {
          finalEntry = remote;
          alreadyUpToDate = true;
        } else {
          conflict = CacheConflict(
            key: request.key,
            type: CacheConflictType.updatedRemotely,
            original: Map<String, dynamic>.from(original),
            local: Map<String, dynamic>.from(updated),
            remote: remote,
          );
          finalEntry = remote;
        }
      }

      var wroteFile = false;
      if (conflict == null && needsWrite && finalEntry != null) {
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(jsonEncode(finalEntry), flush: true);
        await tmp.rename(f.path);
        wroteFile = true;
      }

      return CacheSaveResult(
        key: request.key,
        merged: finalEntry,
        conflict: conflict,
        wroteFile: wroteFile,
        alreadyUpToDate:
            conflict == null && !needsWrite ? alreadyUpToDate : false,
      );
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
  static StandardMergePlan planStandardMerge({
    required StandardDef? original,
    required StandardDef updated,
    required StandardDef? remote,
  }) {
    if (original == null) {
      if (remote == null) {
        return StandardMergePlan(
          finalStandard: updated,
          conflict: null,
          needsWrite: true,
        );
      }
      if (_standardsEqual(remote, updated)) {
        return StandardMergePlan(
          finalStandard: remote,
          conflict: null,
          needsWrite: false,
          alreadyUpToDate: true,
        );
      }
      return StandardMergePlan(
        finalStandard: remote,
        conflict: StandardSaveConflict(
          code: updated.code,
          type: StandardSaveConflictType.alreadyExists,
          original: null,
          local: updated,
          remote: remote,
        ),
        needsWrite: false,
      );
    }

    if (remote == null) {
      return StandardMergePlan(
        finalStandard: null,
        conflict: StandardSaveConflict(
          code: updated.code,
          type: StandardSaveConflictType.deletedRemotely,
          original: original,
          local: updated,
          remote: null,
        ),
        needsWrite: false,
      );
    }

    if (_standardsEqual(remote, original)) {
      if (_standardsEqual(updated, original)) {
        return StandardMergePlan(
          finalStandard: remote,
          conflict: null,
          needsWrite: false,
          alreadyUpToDate: true,
        );
      }
      return StandardMergePlan(
        finalStandard: updated,
        conflict: null,
        needsWrite: true,
      );
    }

    if (_standardsEqual(remote, updated)) {
      return StandardMergePlan(
        finalStandard: remote,
        conflict: null,
        needsWrite: false,
        alreadyUpToDate: true,
      );
    }

    return StandardMergePlan(
      finalStandard: remote,
      conflict: StandardSaveConflict(
        code: updated.code,
        type: StandardSaveConflictType.updatedRemotely,
        original: original,
        local: updated,
        remote: remote,
      ),
      needsWrite: false,
    );
  }

  @visibleForTesting
  static ParameterMergePlan planParametersMerge({
    required List<ParameterDef> original,
    required List<ParameterDef> updated,
    required List<ParameterDef> remote,
  }) {
    final originalMap = _parameterMap(original);
    final localMap = _parameterMap(updated);
    final remoteMap = _parameterMap(remote);

    final mergedMap = <String, ParameterDef>{};
    final conflicts = <ParameterConflict>[];
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
          if (_parametersEqual(local, remoteEntry)) {
            mergedMap[key] = remoteEntry;
          } else {
            conflicts.add(
              ParameterConflict(
                key: local.key.isNotEmpty ? local.key : remoteEntry.key,
                type: ParameterConflictType.addition,
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
        if (_parametersEqual(remoteEntry, orig)) {
          continue;
        }
        conflicts.add(
          ParameterConflict(
            key: orig.key,
            type: ParameterConflictType.removal,
            fields: const {'entry'},
            original: orig,
            local: local,
            remote: remoteEntry,
          ),
        );
        continue;
      }

      if (remoteEntry == null) {
        if (_parametersEqual(local, orig)) {
          continue;
        }
        conflicts.add(
          ParameterConflict(
            key: local.key.isNotEmpty ? local.key : orig.key,
            type: ParameterConflictType.removal,
            fields: const {'entry'},
            original: orig,
            local: local,
            remote: remoteEntry,
          ),
        );
        continue;
      }

      final localChanged = _parameterChangedFields(orig, local);
      final remoteChanged = _parameterChangedFields(orig, remoteEntry);

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
          ParameterConflict(
            key: local.key.isNotEmpty ? local.key : remoteEntry.key,
            type: ParameterConflictType.field,
            fields: intersection,
            original: orig,
            local: local,
            remote: remoteEntry,
          ),
        );
        continue;
      }

      mergedMap[key] = _mergeParameter(remoteEntry, local, localChanged);
    }

    if (conflicts.isNotEmpty) {
      final remoteSorted = _sortedParameters(remote);
      final remoteChanges = _detectParameterRemoteChanges(
        finalMap: remoteMap,
        localMap: localMap,
        originalMap: originalMap,
      );
      return ParameterMergePlan(
        merged: remoteSorted,
        conflicts: conflicts,
        remoteChanges: remoteChanges,
        needsWrite: false,
      );
    }

    final mergedList = _sortedParameters(mergedMap.values.toList());
    final remoteSorted = _sortedParameters(remote);
    final needsWrite = !_parameterListsEqual(mergedList, remoteSorted);
    final remoteChanges = _detectParameterRemoteChanges(
      finalMap: mergedMap,
      localMap: localMap,
      originalMap: originalMap,
    );

    return ParameterMergePlan(
      merged: mergedList,
      conflicts: const [],
      remoteChanges: remoteChanges,
      needsWrite: needsWrite,
    );
  }

  @visibleForTesting
  static DynamicComponentsMergePlan planDynamicComponentsMerge({
    required List<DynamicComponentDef> original,
    required List<DynamicComponentDef> updated,
    required List<DynamicComponentDef> remote,
  }) {
    final originalMap = _dynamicComponentMap(original);
    final localMap = _dynamicComponentMap(updated);
    final remoteMap = _dynamicComponentMap(remote);

    final mergedMap = <String, DynamicComponentDef>{};
    final conflicts = <DynamicComponentConflict>[];
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
          if (_dynamicComponentsEqual(local, remoteEntry)) {
            mergedMap[key] = remoteEntry;
          } else {
            conflicts.add(
              DynamicComponentConflict(
                name: local.name.isNotEmpty ? local.name : remoteEntry.name,
                type: DynamicComponentConflictType.addition,
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
        if (_dynamicComponentsEqual(remoteEntry, orig)) {
          continue;
        }
        conflicts.add(
          DynamicComponentConflict(
            name: orig.name,
            type: DynamicComponentConflictType.removal,
            fields: const {'entry'},
            original: orig,
            local: local,
            remote: remoteEntry,
          ),
        );
        continue;
      }

      if (remoteEntry == null) {
        if (_dynamicComponentsEqual(local, orig)) {
          continue;
        }
        conflicts.add(
          DynamicComponentConflict(
            name: local.name.isNotEmpty ? local.name : orig.name,
            type: DynamicComponentConflictType.removal,
            fields: const {'entry'},
            original: orig,
            local: local,
            remote: remoteEntry,
          ),
        );
        continue;
      }

      final localChanged = _dynamicComponentChangedFields(orig, local);
      final remoteChanged = _dynamicComponentChangedFields(orig, remoteEntry);

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
          DynamicComponentConflict(
            name: local.name.isNotEmpty ? local.name : remoteEntry.name,
            type: DynamicComponentConflictType.field,
            fields: intersection,
            original: orig,
            local: local,
            remote: remoteEntry,
          ),
        );
        continue;
      }

      mergedMap[key] =
          _mergeDynamicComponent(remoteEntry, local, localChanged);
    }

    if (conflicts.isNotEmpty) {
      final remoteSorted = _sortedDynamicComponents(remote);
      final remoteChanges = _detectDynamicRemoteChanges(
        finalMap: remoteMap,
        localMap: localMap,
        originalMap: originalMap,
      );
      return DynamicComponentsMergePlan(
        merged: remoteSorted,
        conflicts: conflicts,
        remoteChanges: remoteChanges,
        needsWrite: false,
      );
    }

    final mergedList = _sortedDynamicComponents(mergedMap.values.toList());
    final remoteSorted = _sortedDynamicComponents(remote);
    final needsWrite = !_dynamicComponentListsEqual(mergedList, remoteSorted);
    final remoteChanges = _detectDynamicRemoteChanges(
      finalMap: mergedMap,
      localMap: localMap,
      originalMap: originalMap,
    );

    return DynamicComponentsMergePlan(
      merged: mergedList,
      conflicts: const [],
      remoteChanges: remoteChanges,
      needsWrite: needsWrite,
    );
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

class StandardMergePlan {
  final StandardDef? finalStandard;
  final StandardSaveConflict? conflict;
  final bool needsWrite;
  final bool alreadyUpToDate;

  const StandardMergePlan({
    required this.finalStandard,
    required this.conflict,
    required this.needsWrite,
    this.alreadyUpToDate = false,
  });
}

class ParameterMergePlan {
  final List<ParameterDef> merged;
  final List<ParameterConflict> conflicts;
  final Set<String> remoteChanges;
  final bool needsWrite;

  const ParameterMergePlan({
    required this.merged,
    required this.conflicts,
    required this.remoteChanges,
    required this.needsWrite,
  });
}

class DynamicComponentsMergePlan {
  final List<DynamicComponentDef> merged;
  final List<DynamicComponentConflict> conflicts;
  final Set<String> remoteChanges;
  final bool needsWrite;

  const DynamicComponentsMergePlan({
    required this.merged,
    required this.conflicts,
    required this.remoteChanges,
    required this.needsWrite,
  });
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

String _canonicalJsonString(Object? value) =>
    jsonEncode(_canonicalizeJson(value));

dynamic _canonicalizeJson(dynamic value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((e) => e.toString()).toList()
      ..sort((a, b) => a.compareTo(b));
    return {
      for (final key in sortedKeys)
        key: _canonicalizeJson(value[key])
    };
  }
  if (value is List) {
    return value.map(_canonicalizeJson).toList();
  }
  return value;
}

bool _mapsDeepEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == null && b == null;
  return _canonicalJsonString(a) == _canonicalJsonString(b);
}

bool _standardsEqual(StandardDef? a, StandardDef? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == null && b == null;
  return _canonicalJsonString(a.toJson()) ==
      _canonicalJsonString(b.toJson());
}

String _normalizeParamKey(String key) => key.trim().toLowerCase();

Map<String, ParameterDef> _parameterMap(List<ParameterDef> list) {
  final map = <String, ParameterDef>{};
  for (final param in list) {
    map[_normalizeParamKey(param.key)] = param;
  }
  return map;
}

bool _parametersEqual(ParameterDef? a, ParameterDef? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == null && b == null;
  return a.key == b.key &&
      a.type == b.type &&
      a.unit == b.unit &&
      listEquals(a.allowedValues, b.allowedValues) &&
      a.required == b.required;
}

dynamic _parameterFieldValue(ParameterDef? def, String field) {
  if (def == null) return null;
  switch (field) {
    case 'key':
      return def.key;
    case 'type':
      return def.type;
    case 'unit':
      return def.unit;
    case 'allowedValues':
      return def.allowedValues;
    case 'required':
      return def.required;
  }
  return null;
}

Set<String> _parameterChangedFields(
  ParameterDef? base,
  ParameterDef? other,
) {
  const fields = {'key', 'type', 'unit', 'allowedValues', 'required'};
  if (base == null || other == null) {
    return {...fields};
  }
  final changed = <String>{};
  for (final field in fields) {
    if (!_valueEquals(
      _parameterFieldValue(base, field),
      _parameterFieldValue(other, field),
    )) {
      changed.add(field);
    }
  }
  return changed;
}

ParameterDef _mergeParameter(
  ParameterDef remote,
  ParameterDef local,
  Set<String> localChanged,
) {
  return ParameterDef(
    key: localChanged.contains('key') ? local.key : remote.key,
    type: localChanged.contains('type') ? local.type : remote.type,
    unit: localChanged.contains('unit') ? local.unit : remote.unit,
    allowedValues: localChanged.contains('allowedValues')
        ? List<String>.from(local.allowedValues)
        : List<String>.from(remote.allowedValues),
    required:
        localChanged.contains('required') ? local.required : remote.required,
  );
}

List<ParameterDef> _sortedParameters(List<ParameterDef> list) {
  final copy = List<ParameterDef>.from(list);
  copy.sort(
    (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()),
  );
  return copy;
}

bool _parameterListsEqual(List<ParameterDef> a, List<ParameterDef> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_parametersEqual(a[i], b[i])) return false;
  }
  return true;
}

Set<String> _detectParameterRemoteChanges({
  required Map<String, ParameterDef> finalMap,
  required Map<String, ParameterDef> localMap,
  required Map<String, ParameterDef> originalMap,
}) {
  final keys = <String>{}
    ..addAll(finalMap.keys)
    ..addAll(localMap.keys);
  final changed = <String>{};
  for (final key in keys) {
    final finalEntry = finalMap[key];
    final localEntry = localMap[key];
    if (!_parametersEqual(finalEntry, localEntry)) {
      final label = finalEntry?.key ??
          localEntry?.key ??
          originalMap[key]?.key ??
          key;
      changed.add(label);
    }
  }
  return changed;
}

String _normalizeComponentName(String name) => name.trim().toLowerCase();

Map<String, DynamicComponentDef> _dynamicComponentMap(
    List<DynamicComponentDef> list) {
  final map = <String, DynamicComponentDef>{};
  for (final component in list) {
    map[_normalizeComponentName(component.name)] = component;
  }
  return map;
}

bool _rulesDeepEqual(List<RuleDef>? a, List<RuleDef>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == null && b == null;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (_canonicalJsonString(a[i].toJson()) !=
        _canonicalJsonString(b[i].toJson())) {
      return false;
    }
  }
  return true;
}

bool _dynamicComponentsEqual(
  DynamicComponentDef? a,
  DynamicComponentDef? b,
) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == null && b == null;
  return a.name == b.name &&
      a.selectionStrategy == b.selectionStrategy &&
      _rulesDeepEqual(a.rules, b.rules);
}

dynamic _dynamicComponentFieldValue(
  DynamicComponentDef? def,
  String field,
) {
  if (def == null) return null;
  switch (field) {
    case 'name':
      return def.name;
    case 'selectionStrategy':
      return def.selectionStrategy;
    case 'rules':
      return def.rules.map((rule) => _canonicalJsonString(rule.toJson())).toList();
  }
  return null;
}

Set<String> _dynamicComponentChangedFields(
  DynamicComponentDef? base,
  DynamicComponentDef? other,
) {
  const fields = {'name', 'selectionStrategy', 'rules'};
  if (base == null || other == null) {
    return {...fields};
  }
  final changed = <String>{};
  for (final field in fields) {
    if (!_valueEquals(
      _dynamicComponentFieldValue(base, field),
      _dynamicComponentFieldValue(other, field),
    )) {
      changed.add(field);
    }
  }
  return changed;
}

DynamicComponentDef _mergeDynamicComponent(
  DynamicComponentDef remote,
  DynamicComponentDef local,
  Set<String> localChanged,
) {
  return DynamicComponentDef(
    name: localChanged.contains('name') ? local.name : remote.name,
    selectionStrategy: localChanged.contains('selectionStrategy')
        ? local.selectionStrategy
        : remote.selectionStrategy,
    rules: localChanged.contains('rules')
        ? List<RuleDef>.from(local.rules)
        : List<RuleDef>.from(remote.rules),
  );
}

List<DynamicComponentDef> _sortedDynamicComponents(
    List<DynamicComponentDef> list) {
  final copy = List<DynamicComponentDef>.from(list);
  copy.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return copy;
}

bool _dynamicComponentListsEqual(
  List<DynamicComponentDef> a,
  List<DynamicComponentDef> b,
) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_dynamicComponentsEqual(a[i], b[i])) return false;
  }
  return true;
}

Set<String> _detectDynamicRemoteChanges({
  required Map<String, DynamicComponentDef> finalMap,
  required Map<String, DynamicComponentDef> localMap,
  required Map<String, DynamicComponentDef> originalMap,
}) {
  final keys = <String>{}
    ..addAll(finalMap.keys)
    ..addAll(localMap.keys);
  final changed = <String>{};
  for (final key in keys) {
    final finalEntry = finalMap[key];
    final localEntry = localMap[key];
    if (!_dynamicComponentsEqual(finalEntry, localEntry)) {
      final label = finalEntry?.name ??
          localEntry?.name ??
          originalMap[key]?.name ??
          key;
      changed.add(label);
    }
  }
  return changed;
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
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_valueEquals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_valueEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
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
