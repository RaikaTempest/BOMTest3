import '../core/models.dart';

abstract class StandardsRepo {
  Future<List<StandardDef>> listStandards();
  Future<void> saveStandard(StandardDef std);
  Future<void> deleteStandard(String code);

  Future<List<ParameterDef>> loadGlobalParameters();
  Future<void> saveGlobalParameters(List<ParameterDef> parameters);

  Future<List<DynamicComponentDef>> loadGlobalDynamicComponents();
  Future<void> saveGlobalDynamicComponents(List<DynamicComponentDef> components);

  Future<void> saveCacheEntry(String key, Map<String, dynamic> entryJson);
  Future<Map<String, dynamic>?> getCacheEntry(String key);
  Future<Map<String, Map<String, dynamic>>> listPendingCache();
  Future<void> approveCache(String key);
  Future<void> rejectCache(String key);
}
