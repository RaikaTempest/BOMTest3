// lib/main.dart
import 'package:flutter/material.dart';
import 'ui/home_screen.dart';

void main() => runApp(const BomApp());

class BomApp extends StatelessWidget {
  const BomApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        textTheme:
            ThemeData.light().textTheme.apply(bodyColor: Colors.black, displayColor: Colors.black),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: colorScheme.primary,
        ),
        tabBarTheme: TabBarTheme(
          labelColor: colorScheme.secondary,
          unselectedLabelColor: colorScheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          indicatorColor: colorScheme.secondary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
