/// Prevents duplicate tab refreshes when nothing useful would change.
class RefreshGate {
  RefreshGate({this.minInterval = const Duration(seconds: 20)});

  final Duration minInterval;
  DateTime? _lastSuccessAt;
  Future<void>? _inFlight;
  String? lastFingerprint;

  bool get hasFreshData {
    final t = _lastSuccessAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < minInterval;
  }

  /// Runs [action] unless a successful fetch happened recently, or one is already in flight.
  /// Pass [force] for pull-to-refresh / explicit retry.
  Future<void> run(Future<void> Function() action, {bool force = false}) {
    if (!force && hasFreshData) {
      return Future.value();
    }
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }
    final future = () async {
      try {
        await action();
        _lastSuccessAt = DateTime.now();
      } finally {
        _inFlight = null;
      }
    }();
    _inFlight = future;
    return future;
  }

  /// Returns true when payload changed and UI should update.
  bool noteFingerprint(String fingerprint) {
    if (lastFingerprint == fingerprint) {
      return false;
    }
    lastFingerprint = fingerprint;
    return true;
  }

  void invalidate() {
    _lastSuccessAt = null;
  }

  void markFresh([String? fingerprint]) {
    _lastSuccessAt = DateTime.now();
    if (fingerprint != null) {
      lastFingerprint = fingerprint;
    }
  }
}
