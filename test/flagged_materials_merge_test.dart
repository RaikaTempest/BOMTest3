import 'package:flutter_test/flutter_test.dart';
import 'package:bom_builder/core/models.dart';
import 'package:bom_builder/data/local_repo.dart';

void main() {
  group('Flagged materials merge', () {
    test('merges disjoint local and remote updates', () {
      final original = [
        const FlaggedMaterial(mm: 'MM1', name: 'Original', note: 'Base'),
      ];
      final updated = [
        const FlaggedMaterial(mm: 'MM1', name: 'Local change', note: 'Base'),
      ];
      final remote = [
        const FlaggedMaterial(mm: 'MM1', name: 'Original', note: 'Remote note'),
      ];

      final plan = LocalStandardsRepo.planFlaggedMaterialsMerge(
        original: original,
        updated: updated,
        remote: remote,
      );

      expect(plan.conflicts, isEmpty);
      expect(plan.merged, hasLength(1));
      expect(plan.merged.single.name, 'Local change');
      expect(plan.merged.single.note, 'Remote note');
      expect(plan.remoteChanges, contains('MM1'));
      expect(plan.needsWrite, isTrue);
    });

    test('detects conflicts when both sides edit the same field', () {
      final original = [
        const FlaggedMaterial(mm: 'MM2', name: 'Original', note: 'Note'),
      ];
      final updated = [
        const FlaggedMaterial(mm: 'MM2', name: 'Local edit', note: 'Note'),
      ];
      final remote = [
        const FlaggedMaterial(mm: 'MM2', name: 'Remote edit', note: 'Note'),
      ];

      final plan = LocalStandardsRepo.planFlaggedMaterialsMerge(
        original: original,
        updated: updated,
        remote: remote,
      );

      expect(plan.conflicts, hasLength(1));
      final conflict = plan.conflicts.single;
      expect(conflict.mm, 'MM2');
      expect(conflict.type, FlaggedMaterialConflictType.field);
      expect(conflict.fields, contains('name'));
      expect(plan.needsWrite, isFalse);
      expect(plan.remoteChanges, contains('MM2'));
      expect(plan.merged.single.name, 'Remote edit');
    });

    test('accepts remote removals when the local entry is untouched', () {
      final original = [
        const FlaggedMaterial(mm: 'MM3', name: 'To remove'),
      ];
      final updated = [
        const FlaggedMaterial(mm: 'MM3', name: 'To remove'),
      ];
      final remote = <FlaggedMaterial>[];

      final plan = LocalStandardsRepo.planFlaggedMaterialsMerge(
        original: original,
        updated: updated,
        remote: remote,
      );

      expect(plan.conflicts, isEmpty);
      expect(plan.merged, isEmpty);
      expect(plan.needsWrite, isFalse);
      expect(plan.remoteChanges, contains('MM3'));
    });
  });
}
