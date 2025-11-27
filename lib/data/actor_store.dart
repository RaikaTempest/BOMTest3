class ActorStore {
  ActorStore._();

  static final ActorStore instance = ActorStore._();

  String? _lastActor;

  String? get lastActor => _lastActor;

  void remember(String actor) {
    final normalized = actor.trim();
    if (normalized.isEmpty) return;
    _lastActor = normalized;
  }
}
