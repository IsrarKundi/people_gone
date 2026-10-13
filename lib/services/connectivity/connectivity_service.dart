/// Connectivity — interface only in Phase 1 (Conventions §1.2). The
/// `connectivity_plus` wrapper implementation lands with the first feature
/// that queues jobs offline (Requirements §6.7).
abstract interface class ConnectivityService {
  /// Emits true when the device has a usable network connection.
  Stream<bool> get online;

  /// Last known state, synchronously.
  bool get isOnline;
}
