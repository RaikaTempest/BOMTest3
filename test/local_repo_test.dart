import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bom_builder/core/models.dart';
import 'package:bom_builder/data/local_repo.dart';

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
      code: 'T1',
      name: 'Test',
      parameters: [],
      staticComponents: [],
      dynamicComponents: [],
    );
    await repo.saveStandard(std);
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

    await repo.saveGlobalParameters(params);
    final loaded = await repo.loadGlobalParameters();

    expect(loaded.length, 2);
    expect(loaded.first.key, params.first.key);
    expect(loaded[1].allowedValues, ['Red', 'Blue']);
  });

  test('concurrent saves serialize without data loss', () async {
    final repoA = LocalStandardsRepo();
    final repoB = LocalStandardsRepo();
    const code = 'CONCURRENT_STD';

    final futures = <Future<void>>[];
    for (var i = 0; i < 20; i++) {
      futures.add(
        repoA.saveStandard(
          StandardDef(
            code: code,
            name: 'RepoA-$i',
            parameters: [
              ParameterDef(key: 'A-$i', type: ParamType.text),
            ],
          ),
        ),
      );
      futures.add(
        repoB.saveStandard(
          StandardDef(
            code: code,
            name: 'RepoB-$i',
            parameters: [
              ParameterDef(key: 'B-$i', type: ParamType.text),
            ],
          ),
        ),
      );
    }

    await Future.wait(futures);

    final standards = await repoA.listStandards();
    expect(standards, hasLength(1));
    final standard = standards.single;
    expect(standard.code, code);
    expect(
      standard.name,
      anyOf([
        for (var i = 0; i < 20; i++) 'RepoA-$i',
        for (var i = 0; i < 20; i++) 'RepoB-$i',
      ]),
    );
    expect(standard.parameters, hasLength(1));
    expect(
      standard.parameters.single.key,
      anyOf([
        for (var i = 0; i < 20; i++) 'A-$i',
        for (var i = 0; i < 20; i++) 'B-$i',
      ]),
    );

    final file = File('${tempDir.path}/bom_data/standards/$code.json');
    expect(await file.exists(), isTrue);
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(() => StandardDef.fromJson(decoded), returnsNormally);
  });
}
