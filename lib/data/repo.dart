import '../core/models.dart';

abstract class StandardsRepo {
  Future<List<StandardDef>> listStandards();
  Future<void> saveStandard(StandardDef std);
  Future<void> deleteStandard(String code);

  Future<List<ParameterDef>> loadGlobalParameters();
  Future<void> saveGlobalParameters(List<ParameterDef> parameters);

  Future<List<DynamicComponentDef>> loadGlobalDynamicComponents();
  Future<void> saveGlobalDynamicComponents(List<DynamicComponentDef> components);

  Future<List<FlaggedMaterial>> loadFlaggedMaterials();
  Future<FlaggedMaterialsSaveResult> saveFlaggedMaterials(
      FlaggedMaterialsSaveRequest request);

  Future<void> saveCacheEntry(String key, Map<String, dynamic> entryJson);
  Future<Map<String, dynamic>?> getCacheEntry(String key);
  Future<Map<String, Map<String, dynamic>>> listPendingCache();
  Future<void> approveCache(String key);
  Future<void> rejectCache(String key);
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
