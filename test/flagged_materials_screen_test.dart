import 'package:bom_builder/core/models.dart';
import 'package:bom_builder/data/repo.dart';
import 'package:bom_builder/ui/flagged_materials_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements StandardsRepo {
  _FakeRepo({required this.initial, required this.saveResult});

  final List<FlaggedMaterial> initial;
  final FlaggedMaterialsSaveResult saveResult;
  FlaggedMaterialsSaveRequest? lastRequest;

  @override
  Future<List<FlaggedMaterial>> loadFlaggedMaterials() async => initial;

  @override
  Future<FlaggedMaterialsSaveResult> saveFlaggedMaterials(
    FlaggedMaterialsSaveRequest request,
  ) async {
    lastRequest = request;
    return saveResult;
  }

  @override
  Future<List<StandardDef>> listStandards() async => throw UnimplementedError();

  @override
  Future<StandardSaveResult> saveStandard(StandardSaveRequest request) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteStandard(String code) async => throw UnimplementedError();

  @override
  Future<List<ParameterDef>> loadGlobalParameters() async => throw UnimplementedError();

  @override
  Future<ParametersSaveResult> saveGlobalParameters(
          ParametersSaveRequest request) async =>
      throw UnimplementedError();

  @override
  Future<List<DynamicComponentDef>> loadGlobalDynamicComponents() async =>
      throw UnimplementedError();

  @override
  Future<DynamicComponentsSaveResult> saveGlobalDynamicComponents(
          DynamicComponentsSaveRequest request) async =>
      throw UnimplementedError();

  @override
  Future<CacheSaveResult> saveCacheEntry(CacheSaveRequest request) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> getCacheEntry(String key) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, Map<String, dynamic>>> listPendingCache() async =>
      throw UnimplementedError();

  @override
  Future<void> approveCache(String key) async => throw UnimplementedError();

  @override
  Future<void> rejectCache(String key) async => throw UnimplementedError();
}

void main() {
  testWidgets('shows a conflict dialog when merges fail', (tester) async {
    final original = const FlaggedMaterial(mm: 'MM10', name: 'Original', note: 'Base');
    final remote = const FlaggedMaterial(mm: 'MM10', name: 'Remote', note: 'Remote note');
    final conflict = FlaggedMaterialConflict(
      mm: original.mm,
      type: FlaggedMaterialConflictType.field,
      fields: const {'note'},
      original: original,
      local: const FlaggedMaterial(mm: 'MM10', name: 'Original', note: 'Local note'),
      remote: remote,
    );
    final repo = _FakeRepo(
      initial: [original],
      saveResult: FlaggedMaterialsSaveResult(
        merged: [remote],
        conflicts: [conflict],
        remoteChanges: const {'MM10'},
        wroteFile: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FlaggedMaterialsScreen(
          repoBuilder: () async => repo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Conflicts detected'), findsOneWidget);
    expect(find.textContaining('MM10'), findsWidgets);
    expect(repo.lastRequest, isNotNull);
    expect(repo.lastRequest!.original.single.mm, original.mm);
  });
}
