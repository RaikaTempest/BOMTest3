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
}
