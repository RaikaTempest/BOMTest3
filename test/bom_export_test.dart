import 'package:flutter_test/flutter_test.dart';
import 'package:bom_builder/core/models.dart';
import 'package:bom_builder/core/bom_exporter.dart';

void main() {
  test('buildCsv aggregates location BOM without flagged section', () {
    final std1 = StandardDef(
      code: 'S1',
      name: 'Std1',
      staticComponents: [StaticComponent(mm: 'MM1', qty: 1)],
    );
    final std2 = StandardDef(
      code: 'S2',
      name: 'Std2',
      dynamicComponents: [
        DynamicComponentDef(name: 'Conn', rules: [
          RuleDef(expr: {'==': [1, 1]}, outputs: [OutputSpec(mm: 'MM2', qty: 2)])
        ])
      ],
    );

    final locations = [
      WorkLocation(barcode: 'L1', standards: {'S1'}),
      WorkLocation(barcode: 'L2', standards: {'S1', 'S2'}),
    ];

    final exporter = BomExporter();
    final csv = exporter.buildCsv(locations, [std1, std2]);
    final lines = csv.trim().split('\n');
    expect(lines.first, 'location,standard,mm,qty,source');
    expect(lines.length, 4);
    expect(lines.contains('L1,S1,MM1,1,static'), isTrue);
    expect(lines.contains('L2,S1,MM1,1,static'), isTrue);
    expect(lines.contains('L2,S2,MM2,2,rule:Conn'), isTrue);
    expect(lines.contains(
      'flagged_mm,name,alternative_available,alternative_mm,alternative_name,note,flagged_at,flagged_by',
    ),
        isFalse);
  });

  test('buildCsv appends flagged materials section when matches exist', () {
    final std1 = StandardDef(
      code: 'S1',
      name: 'Std1',
      staticComponents: [StaticComponent(mm: 'MM1', qty: 1)],
    );
    final std2 = StandardDef(
      code: 'S2',
      name: 'Std2',
      dynamicComponents: [
        DynamicComponentDef(name: 'Conn', rules: [
          RuleDef(expr: {'==': [1, 1]}, outputs: [OutputSpec(mm: 'MM2', qty: 2)])
        ])
      ],
    );

    final locations = [
      WorkLocation(barcode: 'L1', standards: {'S1', 'S2'}),
    ];

    final flagged = [
      FlaggedMaterial(
        mm: 'mm2',
        name: 'Dynamic Material',
        alternativeAvailable: true,
        alternativeMm: 'ALT-2',
        alternativeName: 'Alt Material',
        note: 'Use alternative',
        flaggedAt: DateTime.utc(2023, 1, 1),
        flaggedBy: 'Inspector',
      ),
      FlaggedMaterial(
        mm: 'mm1',
        name: 'Static Material',
        note: 'Discontinue',
        flaggedBy: 'QA',
      ),
      const FlaggedMaterial(mm: 'MMX', name: 'Unused'),
    ];

    final exporter = BomExporter();
    final csv = exporter.buildCsv(
      locations,
      [std1, std2],
      flaggedMaterials: flagged,
    );
    final lines = csv.trim().split('\n');

    expect(lines.first, 'location,standard,mm,qty,source');
    expect(lines.contains('L1,S1,MM1,1,static'), isTrue);
    expect(lines.contains('L1,S2,MM2,2,rule:Conn'), isTrue);

    final headerLine =
        'flagged_mm,name,alternative_available,alternative_mm,alternative_name,note,flagged_at,flagged_by';
    final headerIndex = lines.indexOf(headerLine);
    expect(headerIndex, greaterThan(0));
    expect(lines[headerIndex - 1], '');

    expect(
      lines[headerIndex + 1],
      'mm1,Static Material,false,,,Discontinue,,QA',
    );
    expect(
      lines[headerIndex + 2],
      'mm2,Dynamic Material,true,ALT-2,Alt Material,Use alternative,2023-01-01T00:00:00.000Z,Inspector',
    );
    expect(lines.any((line) => line.contains('MMX')), isFalse);
  });
}
