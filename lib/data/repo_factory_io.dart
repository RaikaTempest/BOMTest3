// lib/data/repo_factory_io.dart
import 'repo.dart';
import 'local_repo.dart';
import 'repo_location_store.dart';

Future<StandardsRepo> getRepo() async {
  final store = RepoLocationStore.instance;
  final override = await store.loadPreferredRoot();
  return LocalStandardsRepo(
    overrideRootPath: override,
    locationStore: store,
  );
}
