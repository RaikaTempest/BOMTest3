import 'dart:convert';
import 'dart:html' as html; // web-only
import '../core/models.dart';
import 'repo.dart';

class WebStandardsRepo implements StandardsRepo {
  static const _kStandards = 'bom_standards';
  static const _kParameters = 'bom_parameters';
  static const _kDynamicComponents = 'bom_dynamic_components';
  static const _kFlaggedMaterials = 'bom_flagged_materials';
  static const _kPending = 'bom_cache_pending';
  static const _kApproved = 'bom_cache_approved';

  Map<String, dynamic> _getMap(String key) {
    final txt = html.window.localStorage[key];
    if (txt == null || txt.isEmpty) return <String, dynamic>{};
    try {
      final j = jsonDecode(txt);
      if (j is Map<String, dynamic>) return j;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void _setMap(String key, Map<String, dynamic> map) {
    html.window.localStorage[key] = jsonEncode(map);
  }

  @override
  Future<List<StandardDef>> listStandards() async {
    final m = _getMap(_kStandards);
    final out = <StandardDef>[];
    for (final e in m.entries) {
      out.add(StandardDef.fromJson((e.value as Map).cast<String, dynamic>()));
    }
    out.sort((a, b) => a.code.compareTo(b.code));
    return out;
  }

  @override
  Future<StandardSaveResult> saveStandard(StandardSaveRequest request) async {
    final updated = request.updated;
    final m = _getMap(_kStandards);
    StandardDef? remote;
    final raw = m[updated.code];
    if (raw is Map) {
      remote = StandardDef.fromJson(raw.cast<String, dynamic>());
    }
    final unchanged = remote != null && _standardEquals(remote, updated);
    if (!unchanged) {
      m[updated.code] = updated.toJson();
      _setMap(_kStandards, m);
    }
    return StandardSaveResult(
      merged: unchanged ? remote : updated,
      conflict: null,
      wroteFile: !unchanged,
      alreadyUpToDate: unchanged,
    );
  }

  @override
  Future<void> deleteStandard(String code) async {
    final m = _getMap(_kStandards);
    m.remove(code);
    _setMap(_kStandards, m);
  }

  @override
  Future<List<ParameterDef>> loadGlobalParameters() async {
    final raw = _getMap(_kParameters);
    final list = <ParameterDef>[];
    final values = raw['items'];
    if (values is List) {
      for (final entry in values) {
        if (entry is Map) {
          list.add(ParameterDef.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }
    return list;
  }

  @override
  Future<ParametersSaveResult> saveGlobalParameters(
      ParametersSaveRequest request) async {
    final updated = request.updated;
    final existing = await loadGlobalParameters();
    final unchanged = _parameterListsEqual(existing, updated);
    if (!unchanged) {
      _setMap(
        _kParameters,
        {
          'items': updated.map((e) => e.toJson()).toList(),
        },
      );
    }
    return ParametersSaveResult(
      merged: List<ParameterDef>.from(updated),
      conflicts: const [],
      remoteChanges: const {},
      wroteFile: !unchanged,
    );
  }

  @override
  Future<List<DynamicComponentDef>> loadGlobalDynamicComponents() async {
    final raw = _getMap(_kDynamicComponents);
    final list = <DynamicComponentDef>[];
    final values = raw['items'];
    if (values is List) {
      for (final entry in values) {
        if (entry is Map) {
          list.add(
            DynamicComponentDef.fromJson(entry.cast<String, dynamic>()),
          );
        }
      }
    }
    return list;
  }

  @override
  Future<DynamicComponentsSaveResult> saveGlobalDynamicComponents(
      DynamicComponentsSaveRequest request) async {
    final updated = request.updated;
    final existing = await loadGlobalDynamicComponents();
    final unchanged = _dynamicComponentListsEqual(existing, updated);
    if (!unchanged) {
      _setMap(
        _kDynamicComponents,
        {
          'items': updated.map((e) => e.toJson()).toList(),
        },
      );
    }
    return DynamicComponentsSaveResult(
      merged: List<DynamicComponentDef>.from(updated),
      conflicts: const [],
      remoteChanges: const {},
      wroteFile: !unchanged,
    );
  }

  @override
  Future<List<FlaggedMaterial>> loadFlaggedMaterials() async {
    final raw = _getMap(_kFlaggedMaterials);
    final list = <FlaggedMaterial>[];
    final values = raw['items'];
    if (values is List) {
      for (final entry in values) {
        if (entry is Map) {
          list.add(
            FlaggedMaterial.fromJson(entry.cast<String, dynamic>()),
          );
        }
      }
    }
    return list;
  }

  @override
  Future<FlaggedMaterialsSaveResult> saveFlaggedMaterials(
      FlaggedMaterialsSaveRequest request) async {
    final items = request.updated;
    _setMap(
      _kFlaggedMaterials,
      {
        'items': items.map((e) => e.toJson()).toList(),
      },
    );
    return FlaggedMaterialsSaveResult(
      merged: List<FlaggedMaterial>.from(items),
      conflicts: const [],
      remoteChanges: const {},
      wroteFile: true,
    );
  }

  @override
  Future<CacheSaveResult> saveCacheEntry(CacheSaveRequest request) async {
    final m = _getMap(_kPending);
    Map<String, dynamic>? remote;
    final raw = m[request.key];
    if (raw is Map) {
      remote = raw.cast<String, dynamic>();
    }
    final updated = Map<String, dynamic>.from(request.updated);
    final unchanged = remote != null && _mapsDeepEqual(remote, updated);
    if (!unchanged) {
      m[request.key] = updated;
      _setMap(_kPending, m);
    }
    return CacheSaveResult(
      key: request.key,
      merged: unchanged ? remote : updated,
      conflict: null,
      wroteFile: !unchanged,
      alreadyUpToDate: unchanged,
    );
  }

  @override
  Future<Map<String, dynamic>?> getCacheEntry(String key) async {
    final p = _getMap(_kPending);
    if (p.containsKey(key)) return (p[key] as Map).cast<String, dynamic>();
    final a = _getMap(_kApproved);
    if (a.containsKey(key)) return (a[key] as Map).cast<String, dynamic>();
    return null;
  }

  @override
  Future<Map<String, Map<String, dynamic>>> listPendingCache() async {
    final p = _getMap(_kPending);
    return p.map((k, v) => MapEntry(k, (v as Map).cast<String, dynamic>()));
  }

  @override
  Future<void> approveCache(String key) async {
    final p = _getMap(_kPending);
    final a = _getMap(_kApproved);
    if (p.containsKey(key)) {
      a[key] = p[key];
      p.remove(key);
      _setMap(_kApproved, a);
      _setMap(_kPending, p);
    }
  }

  @override
  Future<void> rejectCache(String key) async {
    final p = _getMap(_kPending);
    p.remove(key);
    _setMap(_kPending, p);
  }
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

bool _standardEquals(StandardDef? a, StandardDef? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == null && b == null;
  return _canonicalJsonString(a.toJson()) ==
      _canonicalJsonString(b.toJson());
}

bool _parameterListsEqual(
  List<ParameterDef> a,
  List<ParameterDef> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (_canonicalJsonString(a[i].toJson()) !=
        _canonicalJsonString(b[i].toJson())) {
      return false;
    }
  }
  return true;
}

bool _dynamicComponentListsEqual(
  List<DynamicComponentDef> a,
  List<DynamicComponentDef> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (_canonicalJsonString(a[i].toJson()) !=
        _canonicalJsonString(b[i].toJson())) {
      return false;
    }
  }
  return true;
}

bool _mapsDeepEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == null && b == null;
  return _canonicalJsonString(a) == _canonicalJsonString(b);
}
