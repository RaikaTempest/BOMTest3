import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bom_builder/core/models.dart';
import 'package:bom_builder/data/repo.dart';
import 'package:bom_builder/ui/global_parameters_screen.dart';

class _FakeRepo implements StandardsRepo {
  @override
  Future<void> approveCache(String key) async => throw UnimplementedError();

  @override
  Future<void> deleteStandard(String code) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> getCacheEntry(String key) async =>
      throw UnimplementedError();

  @override
  Future<List<DynamicComponentDef>> loadGlobalDynamicComponents() async =>
      throw UnimplementedError();

  @override
  Future<List<ParameterDef>> loadGlobalParameters() async => [];

  @override
  Future<Map<String, Map<String, dynamic>>> listPendingCache() async =>
      throw UnimplementedError();

  @override
  Future<List<StandardDef>> listStandards() async => throw UnimplementedError();

  @override
  Future<void> rejectCache(String key) async => throw UnimplementedError();

  @override
  Future<void> saveCacheEntry(
    String key,
    Map<String, dynamic> entryJson,
  ) async => throw UnimplementedError();

  @override
  Future<void> saveGlobalDynamicComponents(
    List<DynamicComponentDef> components,
  ) async => throw UnimplementedError();

  @override
  Future<void> saveGlobalParameters(List<ParameterDef> parameters) async {}

  @override
  Future<void> saveStandard(StandardDef std) async =>
      throw UnimplementedError();
}

void main() {
  testWidgets('renders Global Parameters screen title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GlobalParametersScreen(repo: _FakeRepo())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Global Parameters'), findsOneWidget);
  });
}
