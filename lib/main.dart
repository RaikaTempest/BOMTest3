// lib/main.dart
import 'package:flutter/material.dart';
import 'ui/home_screen.dart';

void main() => runApp(const BomApp());

class BomApp extends StatelessWidget {
  const BomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
