import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:bom_builder/core/models.dart';
import 'package:bom_builder/data/local_repo.dart';
import 'package:bom_builder/data/repo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_repo_test');
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

  test('saves and reloads a standard', () async {
    final repo = LocalStandardsRepo();
    final std = StandardDef(
      id: const Uuid().v4(),
      code: 'T1',
      name: 'Test',
      parameters: [],
      staticComponents: [],
      dynamicComponents: [],
    );
    await repo.saveStandard(
      StandardSaveRequest(id: std.id, original: null, updated: std),
    );
    final list = await repo.listStandards();
    expect(list.length, 1);
    expect(list.first.code, 'T1');
  });

  test('saves and reloads global parameters', () async {
    final repo = LocalStandardsRepo();
    final params = [
      ParameterDef(key: 'Height', type: ParamType.number, unit: 'ft'),
      ParameterDef(key: 'Color', type: ParamType.enumType, allowedValues: ['Red', 'Blue']),
    ];

    await repo.saveGlobalParameters(
      ParametersSaveRequest(original: const [], updated: params),
    );
    final loaded = await repo.loadGlobalParameters();

    expect(loaded.length, 2);
    expect(loaded.first.key, params.first.key);
    expect(loaded[1].allowedValues, ['Red', 'Blue']);
  });

  test('concurrent saves detect conflicts without corruption', () async {
    final repoA = LocalStandardsRepo();
    final repoB = LocalStandardsRepo();
    const code = 'CONCURRENT_STD';

    final initial = StandardDef(
      id: const Uuid().v4(),
      code: code,
      name: 'Base',
      parameters: [ParameterDef(key: 'BaseParam', type: ParamType.text)],
    );

    final baseResult = await repoA.saveStandard(
      StandardSaveRequest(id: initial.id, original: null, updated: initial),
    );
    expect(baseResult.didSave, isTrue);

    final original = baseResult.merged!;
    final updateA = StandardDef(
      id: original.id,
      code: code,
      name: 'RepoA-update',
      parameters: [ParameterDef(key: 'A', type: ParamType.text)],
    );
    final updateB = StandardDef(
      id: original.id,
      code: code,
      name: 'RepoB-update',
      parameters: [ParameterDef(key: 'B', type: ParamType.text)],
    );

    final results = await Future.wait([
      repoA.saveStandard(
        StandardSaveRequest(id: original.id, original: original, updated: updateA),
      ),
      repoB.saveStandard(
        StandardSaveRequest(id: original.id, original: original, updated: updateB),
      ),
    ]);

    final successes = results.where((r) => r.didSave).toList();
    final conflicts = results.where((r) => r.hasConflicts).toList();
    expect(successes, hasLength(1));
    expect(conflicts, hasLength(1));

    final saved = successes.single.merged!;
    final standards = await repoA.listStandards();
    expect(standards, hasLength(1));
    final standard = standards.single;
    expect(standard.code, code);
    expect(standard.name, saved.name);
    expect(standard.parameters.single.key, saved.parameters.single.key);

    final conflict = conflicts.single.conflict;
    expect(conflict, isNotNull);
    expect(conflict!.type, StandardSaveConflictType.updatedRemotely);

    final file = File('${tempDir.path}/bom_data/standards/$code.json');
    expect(await file.exists(), isTrue);
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(() => StandardDef.fromJson(decoded), returnsNormally);
  });
}
