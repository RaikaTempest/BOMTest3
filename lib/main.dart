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
        appBarTheme: AppBarTheme(
<<<<<<< HEAD
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
=======
          backgroundColor: Colors.white,
          foregroundColor: colorScheme.primary,
        ),
        tabBarTheme: TabBarTheme(
          labelColor: colorScheme.secondary,
          unselectedLabelColor: colorScheme.primary,
          indicatorColor: colorScheme.secondary,
>>>>>>> 1cbe063848be89af69eb021ff57b0574b4a493b0
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
