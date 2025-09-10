// lib/main.dart
import 'package:flutter/material.dart';
import 'ui/debug_repo_screen.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: DebugRepoScreen(),
));
