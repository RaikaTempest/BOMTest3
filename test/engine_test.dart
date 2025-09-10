import 'package:flutter_test/flutter_test.dart';
import 'package:bom_builder/core/models.dart';
import 'package:bom_builder/core/engine.dart';

void main() {
  test('numeric equality treats 4 and 4.0 as equal', () {
    final std = StandardDef(
      code: 'T', name: 'Test',
      parameters: [ParameterDef(key: 'PoleHeight', type: ParamType.number)],
      dynamicComponents: [
        DynamicComponentDef(name: 'Conn', rules: [
          RuleDef(expr: {'==': [ {'var':'PoleHeight'}, 4 ]}, outputs: [OutputSpec(mm: 'MM#X', qty: 1)])
        ])
      ],
    );
    final eng = RuleEngine();
    final bomA = eng.evaluate(std, {'PoleHeight': 4});
    final bomB = eng.evaluate(std, {'PoleHeight': 4.0});
    expect(bomA.length, 1);
    expect(bomB.length, 1);
  });

  test('in operator matches enum values', () {
    final std = StandardDef(
      code: 'T', name: 'Test',
      parameters: [ParameterDef(key: 'Wire', type: ParamType.enumType, allowedValues: ['1/0','2/0'])],
      dynamicComponents: [
        DynamicComponentDef(name: 'Conn', rules: [
          RuleDef(expr: {'in': [ {'var':'Wire'}, ['1/0','2/0'] ]}, outputs: [OutputSpec(mm: 'MM#A', qty: 2)])
        ])
      ],
    );
    final eng = RuleEngine();
    final bom = eng.evaluate(std, {'Wire': '2/0'});
    expect(bom.single.mm, 'MM#A');
    expect(bom.single.qty, 2);
  });

  test('priority and specificity choose the right rule', () {
    final std = StandardDef(
      code: 'T', name: 'Test',
      parameters: [ParameterDef(key: 'PoleHeight', type: ParamType.number)],
      dynamicComponents: [
        DynamicComponentDef(name: 'Conn', rules: [
          RuleDef(priority: 0, expr: {'>=': [ {'var':'PoleHeight'}, 30 ]}, outputs: [OutputSpec(mm: 'MM#LOW', qty: 1)]),
          RuleDef(priority: 1, expr: {'and': [ {'>=': [{'var':'PoleHeight'}, 30]}, {'<=': [{'var':'PoleHeight'}, 40]} ]}, outputs: [OutputSpec(mm: 'MM#MID', qty: 1)])
        ])
      ],
    );
    final eng = RuleEngine();
    final bom = eng.evaluate(std, {'PoleHeight': 35});
    expect(bom.single.mm, 'MM#MID');
  });

  test('qty formula computes simple arithmetic', () {
    final std = StandardDef(
      code: 'T', name: 'Test',
      parameters: [ParameterDef(key: 'span_ft', type: ParamType.number)],
      dynamicComponents: [
        DynamicComponentDef(name: 'Conn', rules: [
          RuleDef(expr: {'>': [ {'var':'span_ft'}, 0 ]}, outputs: [OutputSpec(mm: 'MM#CLAMP', qtyFormula: 'span_ft/10*3')])
        ])
      ],
    );
    final eng = RuleEngine();
    final bom = eng.evaluate(std, {'span_ft': 20});
    expect(bom.single.mm, 'MM#CLAMP');
    expect(bom.single.qty, 6); // 20/10*3
  });
}