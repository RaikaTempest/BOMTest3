import 'dart:convert';
import 'dart:html' as html; // web-only
import '../core/models.dart';
import 'repo.dart';

class WebStandardsRepo implements StandardsRepo {
  static const _kStandards = 'bom_standards';
  static const _kParameters = 'bom_parameters';
  static const _kDynamicComponents = 'bom_dynamic_components';
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
  Future<void> saveStandard(StandardDef std) async {
    final m = _getMap(_kStandards);
    m[std.code] = std.toJson();
    _setMap(_kStandards, m);
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
  Future<void> saveGlobalParameters(List<ParameterDef> parameters) async {
    _setMap(
      _kParameters,
      {
        'items': parameters.map((e) => e.toJson()).toList(),
      },
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
  Future<void> saveGlobalDynamicComponents(
      List<DynamicComponentDef> components) async {
    _setMap(
      _kDynamicComponents,
      {
        'items': components.map((e) => e.toJson()).toList(),
      },
    );
  }

  @override
  Future<void> saveCacheEntry(String key, Map<String, dynamic> entryJson) async {
    final m = _getMap(_kPending);
    m[key] = entryJson;
    _setMap(_kPending, m);
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
