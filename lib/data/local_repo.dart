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
    final aliasesFile = File('${root.path}/aliases.json');
    if (!await aliasesFile.exists()) {
      await aliasesFile.writeAsString(jsonEncode({}), flush: true);
    }
    _root = root;
    return root;
  }

  Future<File> _stdFile(String code) async {
    final r = await _ensureRoot();
    return File('${r.path}/standards/$code.json');
  }

  Future<File> _aliasesFile() async {
    final r = await _ensureRoot();
    return File('${r.path}/aliases.json');
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
    out.sort((a,b)=>a.code.compareTo(b.code));
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
  Future<Map<String, String>> loadAliases() async {
    final f = await _aliasesFile();
    final txt = await f.readAsString();
    final j = jsonDecode(txt) as Map<String, dynamic>;
    return j.map((k,v)=>MapEntry(k, v.toString()));
  }

  @override
  Future<void> saveAliases(Map<String, String> aliases) async {
    final f = await _aliasesFile();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(aliases), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> saveCacheEntry(String key, Map<String, dynamic> entryJson) async {
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
