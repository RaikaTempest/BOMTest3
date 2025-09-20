import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef _DocumentsDirectoryProvider = Future<Directory> Function();

class RepoLocationStore {
  RepoLocationStore._({
    _DocumentsDirectoryProvider? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  factory RepoLocationStore({
    _DocumentsDirectoryProvider? documentsDirectoryProvider,
  }) =
      RepoLocationStore._;

  static final RepoLocationStore instance = RepoLocationStore._();

  final _DocumentsDirectoryProvider _documentsDirectoryProvider;
  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();
  String? _cachedPath;
  bool _loaded = false;

  Stream<String?> get changes => _controller.stream;

  Future<File> _configFile() async {
    final dir = await _documentsDirectoryProvider();
    final configDir = Directory('${dir.path}/bom_prefs');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return File('${configDir.path}/repo_location.json');
  }

  Future<String?> loadPreferredRoot() async {
    if (_loaded) return _cachedPath;
    final file = await _configFile();
    if (await file.exists()) {
      try {
        final text = await file.readAsString();
        if (text.trim().isNotEmpty) {
          final data = jsonDecode(text);
          if (data is Map && data['path'] is String) {
            _cachedPath = data['path'] as String;
          }
        }
      } catch (_) {
        _cachedPath = null;
      }
    }
    _loaded = true;
    return _cachedPath;
  }

  Future<void> setPreferredRoot(String? path) async {
    final file = await _configFile();
    if (path == null || path.trim().isEmpty) {
      if (await file.exists()) {
        await file.delete();
      }
      _cachedPath = null;
    } else {
      final normalized = path.trim();
      await file.writeAsString(jsonEncode({'path': normalized}), flush: true);
      _cachedPath = normalized;
    }
    _loaded = true;
    _controller.add(_cachedPath);
  }

  Future<String> resolveRootPath() async {
    final stored = await loadPreferredRoot();
    if (stored != null && stored.trim().isNotEmpty) {
      return stored;
    }
    final dir = await _documentsDirectoryProvider();
    return '${dir.path}/bom_data';
  }
}
