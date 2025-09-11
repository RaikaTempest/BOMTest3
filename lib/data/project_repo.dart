// lib/data/project_repo.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/models.dart';

class LocalProjectRepo {
  Directory? _root;

  Future<Directory> _ensureRoot() async {
    if (_root != null) return _root!;
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory('${dir.path}/projects');
    await root.create(recursive: true);
    _root = root;
    return root;
  }

  Future<File> _file(String name) async {
    final r = await _ensureRoot();
    return File('${r.path}/$name.json');
  }

  Future<void> saveProject(Project p) async {
    final f = await _file(p.name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(p.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  Future<Project?> loadProject(String name) async {
    final f = await _file(name);
    if (!await f.exists()) return null;
    final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    return Project.fromJson(j);
  }

  Future<List<String>> listProjects() async {
    final r = await _ensureRoot();
    final dir = r;
    final out = <String>[];
    await for (final f in dir.list()) {
      if (f is File && f.path.endsWith('.json')) {
        out.add(f.uri.pathSegments.last.replaceFirst('.json', ''));
      }
    }
    out.sort();
    return out;
  }
}
