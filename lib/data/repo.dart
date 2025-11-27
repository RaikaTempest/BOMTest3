import '../core/models.dart';

abstract class StandardsRepo {
  Future<List<StandardDef>> listStandards();
  Future<StandardSaveResult> saveStandard(StandardSaveRequest request,
      {String? actor, bool audit = false});
  Future<void> deleteStandard(String code, {String? actor, bool audit = false});

  Future<List<ParameterDef>> loadGlobalParameters();
  Future<ParametersSaveResult> saveGlobalParameters(
      ParametersSaveRequest request);

  Future<List<DynamicComponentDef>> loadGlobalDynamicComponents();
  Future<DynamicComponentsSaveResult> saveGlobalDynamicComponents(
      DynamicComponentsSaveRequest request);

  Future<List<FlaggedMaterial>> loadFlaggedMaterials();
  Future<FlaggedMaterialsSaveResult> saveFlaggedMaterials(
      FlaggedMaterialsSaveRequest request);

  Future<CacheSaveResult> saveCacheEntry(CacheSaveRequest request);
  Future<Map<String, dynamic>?> getCacheEntry(String key);
  Future<Map<String, Map<String, dynamic>>> listPendingCache();
  Future<void> approveCache(String key, {String? actor, bool audit = false});
  Future<void> rejectCache(String key);
}

class StandardSaveRequest {
  final String id;
  final StandardDef? original;
  final StandardDef updated;

  StandardSaveRequest({
    required this.id,
    this.original,
    required this.updated,
  })  : assert(id.isNotEmpty, 'StandardSaveRequest id cannot be empty'),
        assert(id == updated.id,
            'StandardSaveRequest id must match updated standard id'),
        assert(original == null || original.id == id,
            'StandardSaveRequest id must match original standard id');
}

enum StandardSaveConflictType { alreadyExists, updatedRemotely, deletedRemotely }

class StandardSaveConflict {
  final String id;
  final String code;
  final StandardSaveConflictType type;
  final StandardDef? original;
  final StandardDef? local;
  final StandardDef? remote;

  const StandardSaveConflict({
    required this.id,
    required this.code,
    required this.type,
    this.original,
    this.local,
    this.remote,
  });
}

class StandardSaveResult {
  final StandardDef? merged;
  final StandardSaveConflict? conflict;
  final bool wroteFile;
  final bool alreadyUpToDate;

  const StandardSaveResult({
    required this.merged,
    this.conflict,
    required this.wroteFile,
    this.alreadyUpToDate = false,
  });

  bool get didSave => conflict == null && (wroteFile || alreadyUpToDate);
  bool get hasConflicts => conflict != null;
}

class ParametersSaveRequest {
  final List<ParameterDef> original;
  final List<ParameterDef> updated;

  const ParametersSaveRequest({
    required this.original,
    required this.updated,
  });
}

enum ParameterConflictType { addition, removal, field }

class ParameterConflict {
  final String key;
  final ParameterConflictType type;
  final Set<String> fields;
  final ParameterDef? original;
  final ParameterDef? local;
  final ParameterDef? remote;

  const ParameterConflict({
    required this.key,
    required this.type,
    this.fields = const {},
    this.original,
    this.local,
    this.remote,
  });
}

class ParametersSaveResult {
  final List<ParameterDef> merged;
  final List<ParameterConflict> conflicts;
  final Set<String> remoteChanges;
  final bool wroteFile;

  const ParametersSaveResult({
    required this.merged,
    required this.conflicts,
    required this.remoteChanges,
    required this.wroteFile,
  });

  bool get didSave => conflicts.isEmpty;
  bool get hasConflicts => conflicts.isNotEmpty;
  bool get hasRemoteChanges => remoteChanges.isNotEmpty;
}

class DynamicComponentsSaveRequest {
  final List<DynamicComponentDef> original;
  final List<DynamicComponentDef> updated;

  const DynamicComponentsSaveRequest({
    required this.original,
    required this.updated,
  });
}

enum DynamicComponentConflictType { addition, removal, field }

class DynamicComponentConflict {
  final String name;
  final DynamicComponentConflictType type;
  final Set<String> fields;
  final DynamicComponentDef? original;
  final DynamicComponentDef? local;
  final DynamicComponentDef? remote;

  const DynamicComponentConflict({
    required this.name,
    required this.type,
    this.fields = const {},
    this.original,
    this.local,
    this.remote,
  });
}

class DynamicComponentsSaveResult {
  final List<DynamicComponentDef> merged;
  final List<DynamicComponentConflict> conflicts;
  final Set<String> remoteChanges;
  final bool wroteFile;

  const DynamicComponentsSaveResult({
    required this.merged,
    required this.conflicts,
    required this.remoteChanges,
    required this.wroteFile,
  });

  bool get didSave => conflicts.isEmpty;
  bool get hasConflicts => conflicts.isNotEmpty;
  bool get hasRemoteChanges => remoteChanges.isNotEmpty;
}

class CacheSaveRequest {
  final String key;
  final Map<String, dynamic>? original;
  final Map<String, dynamic> updated;

  const CacheSaveRequest({
    required this.key,
    this.original,
    required this.updated,
  });
}

enum CacheConflictType { alreadyExists, updatedRemotely, deletedRemotely }

class CacheConflict {
  final String key;
  final CacheConflictType type;
  final Map<String, dynamic>? original;
  final Map<String, dynamic>? local;
  final Map<String, dynamic>? remote;

  const CacheConflict({
    required this.key,
    required this.type,
    this.original,
    this.local,
    this.remote,
  });
}

class CacheSaveResult {
  final String key;
  final Map<String, dynamic>? merged;
  final CacheConflict? conflict;
  final bool wroteFile;
  final bool alreadyUpToDate;

  const CacheSaveResult({
    required this.key,
    this.merged,
    this.conflict,
    required this.wroteFile,
    this.alreadyUpToDate = false,
  });

  bool get didSave => conflict == null && (wroteFile || alreadyUpToDate);
  bool get hasConflicts => conflict != null;
}

class FlaggedMaterialsSaveRequest {
  final List<FlaggedMaterial> original;
  final List<FlaggedMaterial> updated;

  const FlaggedMaterialsSaveRequest({
    required this.original,
    required this.updated,
  });
}

enum FlaggedMaterialConflictType { addition, removal, field }

class FlaggedMaterialConflict {
  final String mm;
  final FlaggedMaterialConflictType type;
  final Set<String> fields;
  final FlaggedMaterial? original;
  final FlaggedMaterial? local;
  final FlaggedMaterial? remote;

  const FlaggedMaterialConflict({
    required this.mm,
    required this.type,
    this.fields = const {},
    this.original,
    this.local,
    this.remote,
  });
}

class FlaggedMaterialsSaveResult {
  final List<FlaggedMaterial> merged;
  final List<FlaggedMaterialConflict> conflicts;
  final Set<String> remoteChanges;
  final bool wroteFile;

  const FlaggedMaterialsSaveResult({
    required this.merged,
    required this.conflicts,
    required this.remoteChanges,
    required this.wroteFile,
  });

  bool get didSave => conflicts.isEmpty;
  bool get hasConflicts => conflicts.isNotEmpty;
  bool get hasRemoteChanges => remoteChanges.isNotEmpty;
}
