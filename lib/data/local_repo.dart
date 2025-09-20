// lib/data/local_repo.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/models.dart';
import 'repo.dart';

class LocalStandardsRepo implements StandardsRepo {
  Directory? _root;

  Future<Directory> _ensureRoot() async {
    if (_root != null) return _root!;
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory('${dir.path}/bom_data');
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
      await dynamicComponentsFile.writeAsString(
        jsonEncode(<dynamic>[]),
        flush: true,
      );
    }
    _root = root;
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

  Future<File> _pendingFile(String key) async {
    final r = await _ensureRoot();
    return File('${r.path}/cache/pending/$key.json');
  }

  Future<File> _approvedFile(String key) async {
    final r = await _ensureRoot();
    return File('${r.path}/cache/approved/$key.json');
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
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(std.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> deleteStandard(String code) async {
    final f = await _stdFile(code);
    if (await f.exists()) await f.delete();
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
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
      jsonEncode(parameters.map((e) => e.toJson()).toList()),
      flush: true,
    );
    await tmp.rename(f.path);
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
            (e) => DynamicComponentDef.fromJson(
              (e as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    }
    return [];
  }

  @override
  Future<void> saveGlobalDynamicComponents(
    List<DynamicComponentDef> components,
  ) async {
    final f = await _dynamicComponentsFile();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
      jsonEncode(components.map((e) => e.toJson()).toList()),
      flush: true,
    );
    await tmp.rename(f.path);
  }

  @override
  Future<void> saveCacheEntry(
    String key,
    Map<String, dynamic> entryJson,
  ) async {
    final f = await _pendingFile(key);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(entryJson), flush: true);
    await tmp.rename(f.path);
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
    if (!await src.exists()) return;
    final dst = await _approvedFile(key);
    final tmp = File('${dst.path}.tmp');
    await tmp.writeAsString(await src.readAsString(), flush: true);
    await tmp.rename(dst.path);
    await src.delete();
  }

  @override
  Future<void> rejectCache(String key) async {
    final f = await _pendingFile(key);
    if (await f.exists()) await f.delete();
  }
}
