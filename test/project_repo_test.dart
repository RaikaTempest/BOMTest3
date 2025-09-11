import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bom_builder/core/models.dart';
import 'package:bom_builder/data/project_repo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('project_repo_test');
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  tearDown(() async {
    channel.setMockMethodCallHandler(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves and loads project', () async {
    final repo = LocalProjectRepo();
    final proj = Project(name: 'p1', locations: [WorkLocation(barcode: 'a')]);
    await repo.saveProject(proj);
    final list = await repo.listProjects();
    expect(list, ['p1']);
    final loaded = await repo.loadProject('p1');
    expect(loaded?.locations.first.barcode, 'a');
  });
}
