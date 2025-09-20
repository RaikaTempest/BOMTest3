import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bom_builder/ui/standards_manager_screen.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final binaryMessenger = binding.defaultBinaryMessenger;

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('standards_manager_test');
    binaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    binaryMessenger.setMockMethodCallHandler(channel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('renders Standards manager screen title', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StandardsManagerScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Standards'), findsOneWidget);
  });
}

