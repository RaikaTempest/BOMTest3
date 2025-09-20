// lib/data/repo_factory_web.dart
import 'repo.dart';
import 'web_repo.dart';

Future<StandardsRepo> getRepo() async => WebStandardsRepo();
