// lib/data/repo_factory.dart
import 'repo.dart';
import 'repo_factory_io.dart'
    if (dart.library.html) 'repo_factory_web.dart' as impl;

StandardsRepo createRepo() => impl.getRepo();
