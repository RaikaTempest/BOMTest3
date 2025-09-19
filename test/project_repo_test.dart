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

  test('archives and unarchives projects', () async {
    final repo = LocalProjectRepo();
    await repo.saveProject(Project(name: 'p1', locations: []));
    await repo.saveProject(Project(name: 'p2', locations: []));

    await repo.archiveProject('p1');
    expect(await repo.listProjects(), ['p2']);
    expect(await repo.listProjects(archived: true), ['p1']);

    final archived = await repo.loadProject('p1', archived: true);
    expect(archived?.name, 'p1');

    await repo.unarchiveProject('p1');
    expect(await repo.listProjects(), ['p1', 'p2']);
    expect(await repo.listProjects(archived: true), isEmpty);
  });

  test('saving project removes archived copy', () async {
    final repo = LocalProjectRepo();
    final proj = Project(name: 'p1', locations: []);
    await repo.saveProject(proj);
    await repo.archiveProject('p1');

    expect(await repo.listProjects(), isEmpty);
    expect(await repo.listProjects(archived: true), ['p1']);

    final updated = Project(
      name: 'p1',
      locations: [WorkLocation(barcode: 'z')],
    );
    await repo.saveProject(updated);

    expect(await repo.listProjects(), ['p1']);
    expect(await repo.listProjects(archived: true), isEmpty);

    final loaded = await repo.loadProject('p1');
    expect(loaded?.locations.first.barcode, 'z');
  });
}
