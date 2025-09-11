import 'package:flutter_test/flutter_test.dart';
import 'package:bom_builder/core/models.dart';
import 'package:bom_builder/core/bom_exporter.dart';

void main() {
  test('buildCsv aggregates location BOM', () {
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
  });
}
