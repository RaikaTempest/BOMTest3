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

  Future<Directory> _ensureArchiveRoot() async {
    final root = await _ensureRoot();
    final archived = Directory('${root.path}/archived');
    await archived.create(recursive: true);
    return archived;
  }

  Future<File> _file(String name, {bool archived = false}) async {
    final dir = archived ? await _ensureArchiveRoot() : await _ensureRoot();
    return File('${dir.path}/$name.json');
  }

  Future<void> saveProject(Project p) async {
    final activeFile = await _file(p.name);
    final archivedFile = await _file(p.name, archived: true);
    if (await archivedFile.exists()) {
      await archivedFile.delete();
    }
    final tmp = File('${activeFile.path}.tmp');
    await tmp.writeAsString(jsonEncode(p.toJson()), flush: true);
    await tmp.rename(activeFile.path);
  }

  Future<Project?> loadProject(String name, {bool archived = false}) async {
    final f = await _file(name, archived: archived);
    if (!await f.exists()) return null;
    final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    return Project.fromJson(j);
  }

  Future<List<String>> listProjects({bool archived = false}) async {
    final dir = archived ? await _ensureArchiveRoot() : await _ensureRoot();
    final out = <String>[];
    await for (final f in dir.list()) {
      if (f is File && f.path.endsWith('.json')) {
        out.add(f.uri.pathSegments.last.replaceFirst('.json', ''));
      }
    }
    out.sort();
    return out;
  }

  Future<void> archiveProject(String name) async {
    final source = await _file(name);
    if (!await source.exists()) return;
    final destination = await _file(name, archived: true);
    if (await destination.exists()) {
      await destination.delete();
    }
    await source.rename(destination.path);
  }

  Future<void> unarchiveProject(String name) async {
    final source = await _file(name, archived: true);
    if (!await source.exists()) return;
    final destination = await _file(name);
    if (await destination.exists()) {
      await destination.delete();
    }
    await source.rename(destination.path);
  }
}
