import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef _DocumentsDirectoryProvider = Future<Directory> Function();

class AdminCredentialsStore {
  AdminCredentialsStore._({
    this.defaultPassword = _defaultAdminPassword,
    _DocumentsDirectoryProvider? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  factory AdminCredentialsStore({
    String defaultPassword = _defaultAdminPassword,
    _DocumentsDirectoryProvider? documentsDirectoryProvider,
  }) =>
      AdminCredentialsStore._(
        defaultPassword: defaultPassword,
        documentsDirectoryProvider: documentsDirectoryProvider,
      );

  static final AdminCredentialsStore instance = AdminCredentialsStore._();

  static const String _defaultAdminPassword = 'admin';

  final String defaultPassword;
  final _DocumentsDirectoryProvider _documentsDirectoryProvider;
  String? _cachedPassword;
  bool _loaded = false;

  Future<File> _configFile() async {
    final dir = await _documentsDirectoryProvider();
    final configDir = Directory('${dir.path}/bom_prefs');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return File('${configDir.path}/admin_credentials.json');
  }

  Future<String> loadAdminPassword() async {
    if (_loaded) return _cachedPassword ?? defaultPassword;
    final file = await _configFile();
    if (await file.exists()) {
      try {
        final text = await file.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is Map && decoded['password'] is String) {
          _cachedPassword = (decoded['password'] as String).trim();
        }
      } catch (_) {
        _cachedPassword = null;
      }
    }
    _loaded = true;
    return _cachedPassword == null || _cachedPassword!.isEmpty
        ? defaultPassword
        : _cachedPassword!;
  }

  Future<void> setAdminPassword(String password) async {
    final normalized = password.trim();
    final file = await _configFile();
    await file.writeAsString(jsonEncode({'password': normalized}), flush: true);
    _cachedPassword = normalized;
    _loaded = true;
  }
}
