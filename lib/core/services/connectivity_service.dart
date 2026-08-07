import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service gérant la détection de la connexion réseau (online/offline).
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Vérifie si l'appareil est actuellement connecté à Internet.
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return _hasConnection(result);
  }

  /// Flux informant des changements d'état de connexion.
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_hasConnection);
  }

  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}

/// Provider pour le service de connectivité.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Provider réactif indiquant si l'application est en ligne (true) ou hors-ligne (false).
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  // Émettre l'état initial
  yield await service.isOnline;
  // Émettre lors des changements de réseau
  yield* service.onConnectivityChanged;
});
