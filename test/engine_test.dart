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

  test('static component can borrow MM from dynamic provider', () {
    final std = StandardDef(
      code: 'T',
      name: 'Test',
      staticComponents: [
        StaticComponent(mm: 'MM#FALLBACK', dynamicMmComponent: 'Conn', qty: 5),
      ],
      dynamicComponents: [
        DynamicComponentDef(name: 'Conn', rules: [
          RuleDef(
            expr: {
              '==': [
                {'var': 'size'},
                'large',
              ]
            },
            outputs: [OutputSpec(mm: 'MM#LARGE', qty: 1)],
          ),
          RuleDef(
            expr: {
              '==': [
                {'var': 'size'},
                'small',
              ]
            },
            outputs: [OutputSpec(mm: 'MM#SMALL', qty: 1)],
          ),
        ]),
      ],
    );

    final eng = RuleEngine();
    final bom = eng.evaluate(std, {'size': 'small'});

    expect(
      bom.any(
        (line) => line.source == 'static:Conn' && line.mm == 'MM#SMALL' && line.qty == 5,
      ),
      isTrue,
    );
  });

  test('matrix generates part number for valid combination', () {
    final std = StandardDef(
      code: 'T',
      name: 'Test',
      parameters: [
        ParameterDef(key: 'wire1', type: ParamType.enumType, allowedValues: ['1/0']),
        ParameterDef(key: 'wire2', type: ParamType.enumType, allowedValues: ['2/0']),
      ],
      dynamicComponents: [
        DynamicComponentDef(
          name: 'Conn',
          matrix: ConnectorMatrix(
            axis1Parameter: 'wire1',
            axis2Parameter: 'wire2',
            rows: [
              ConnectorMatrixRow(
                axis1Value: '1/0',
                cells: [ConnectorMatrixCell(axis2Value: '2/0', mm: 'MM#1200')],
              ),
            ],
          ),
        ),
      ],
    );
    final eng = RuleEngine();
    final bom = eng.evaluate(std, {'wire1': '1/0', 'wire2': '2/0'});
    expect(bom.single.mm, 'MM#1200');
    expect(bom.single.source, 'matrix:Conn');
    expect(bom.single.status, 'ok');
  });

  test('matrix can use pattern to generate SKU when mm missing', () {
    final std = StandardDef(
      code: 'T',
      name: 'Test',
      parameters: [
        ParameterDef(key: 'wire1', type: ParamType.enumType, allowedValues: ['1/0']),
        ParameterDef(key: 'wire2', type: ParamType.enumType, allowedValues: ['2/0']),
      ],
      dynamicComponents: [
        DynamicComponentDef(
          name: 'Conn',
          mmPattern: 'AMP-{axis1}-{axis2}',
          matrix: ConnectorMatrix(
            axis1Parameter: 'wire1',
            axis2Parameter: 'wire2',
            rows: [
              ConnectorMatrixRow(
                axis1Value: '1/0',
                cells: [ConnectorMatrixCell(axis2Value: '2/0')],
              ),
            ],
          ),
        ),
      ],
    );
    final eng = RuleEngine();
    final bom = eng.evaluate(std, {'wire1': '1/0', 'wire2': '2/0'});
    expect(bom.single.mm, 'AMP-1/0-2/0');
    expect(bom.single.source, 'matrix:Conn');
  });

  test('matrix marks missing combination as invalid', () {
    final std = StandardDef(
      code: 'T',
      name: 'Test',
      parameters: [
        ParameterDef(key: 'wire1', type: ParamType.enumType, allowedValues: ['1/0']),
        ParameterDef(key: 'wire2', type: ParamType.enumType, allowedValues: ['2/0', '4/0']),
      ],
      dynamicComponents: [
        DynamicComponentDef(
          name: 'Conn',
          matrix: ConnectorMatrix(
            axis1Parameter: 'wire1',
            axis2Parameter: 'wire2',
            rows: [
              ConnectorMatrixRow(
                axis1Value: '1/0',
                cells: [ConnectorMatrixCell(axis2Value: '2/0', mm: 'MM#1200')],
              ),
            ],
          ),
        ),
      ],
    );
    final eng = RuleEngine();
    final bom = eng.evaluate(std, {'wire1': '1/0', 'wire2': '4/0'});
    expect(bom.single.status, 'invalid');
    expect(bom.single.qty, 0);
    expect(bom.single.mm, 'INVALID');
    expect(bom.single.notes, contains('No combination'));
  });

  test('matrix propagates accessory flags and notes', () {
    final std = StandardDef(
      code: 'T',
      name: 'Test',
      parameters: [
        ParameterDef(key: 'wire1', type: ParamType.enumType, allowedValues: ['1/0']),
        ParameterDef(key: 'wire2', type: ParamType.enumType, allowedValues: ['2/0']),
      ],
      dynamicComponents: [
        DynamicComponentDef(
          name: 'Conn',
          matrix: ConnectorMatrix(
            axis1Parameter: 'wire1',
            axis2Parameter: 'wire2',
            rows: [
              ConnectorMatrixRow(
                axis1Value: '1/0',
                cells: [
                  ConnectorMatrixCell(
                    axis2Value: '2/0',
                    mm: 'MM#1200',
                    requiresAccessory: true,
                    notes: 'Use reducer sleeve',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final eng = RuleEngine();
    final bom = eng.evaluate(std, {'wire1': '1/0', 'wire2': '2/0'});
    final line = bom.single;
    expect(line.requiresAccessory, isTrue);
    expect(line.notes, 'Use reducer sleeve');
  });

  test('matrix falls back to rules when no SKU is provided', () {
    final std = StandardDef(
      code: 'T',
      name: 'Test',
      parameters: [
        ParameterDef(key: 'wire1', type: ParamType.enumType, allowedValues: ['1/0']),
        ParameterDef(key: 'wire2', type: ParamType.enumType, allowedValues: ['2/0']),
      ],
      dynamicComponents: [
        DynamicComponentDef(
          name: 'Conn',
          matrix: ConnectorMatrix(
            axis1Parameter: 'wire1',
            axis2Parameter: 'wire2',
            rows: [
              ConnectorMatrixRow(
                axis1Value: '1/0',
                cells: [ConnectorMatrixCell(axis2Value: '2/0')],
              ),
            ],
          ),
          rules: [
            RuleDef(
              expr: {
                'and': [
                  {'==': [
                    {'var': 'wire1'},
                    '1/0',
                  ]},
                  {'==': [
                    {'var': 'wire2'},
                    '2/0',
                  ]},
                ],
              },
              outputs: [OutputSpec(mm: 'MM#RULE', qty: 1)],
            ),
          ],
        ),
      ],
    );
    final eng = RuleEngine();
    final bom = eng.evaluate(std, {'wire1': '1/0', 'wire2': '2/0'});
    expect(bom.single.mm, 'MM#RULE');
    expect(bom.single.source, 'rule:Conn');
  });
}

