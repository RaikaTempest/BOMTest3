import 'package:bom_builder/core/models.dart';
import 'package:bom_builder/ui/dynamic_component_rules_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DynamicComponentDef buildComponent() {
    return DynamicComponentDef(
      name: 'Test Component',
      rules: [
        RuleDef(
          expr: {
            '==': [
              {'var': 'voltage'},
              120,
            ],
          },
          outputs: [
            OutputSpec(mm: 'MM-1', qty: 2),
          ],
          priority: 10,
        ),
      ],
    );
  }

  List<ParameterDef> buildParameters() {
    return [
      ParameterDef(key: 'voltage', type: ParamType.number),
    ];
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DynamicComponentRulesScreen(
          component: buildComponent(),
          parameters: buildParameters(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows duplicate action on each rule card', (tester) async {
    await pumpScreen(tester);

    expect(find.widgetWithText(TextButton, 'Duplicate'), findsOneWidget);
  });

  testWidgets('duplicating a rule creates a second rule with same initial content', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Duplicate'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Rule duplicated'), findsOneWidget);
    expect(find.text('Outputs: MM-1 × 2'), findsNWidgets(2));
    expect(find.text('When: voltage == 120'), findsNWidgets(2));
  });

  testWidgets('editing duplicated rule updates only duplicated entry', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Duplicate'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Priority'), '5');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Priority: 10'), findsOneWidget);
    expect(find.text('Priority: 5'), findsOneWidget);
  });
}
