import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'storage_service.dart';
import 'supabase_service.dart';

/// Racine de l'injection de dépendances.
///
/// Chaque feature déclare ses propres providers (repository + state) et les
/// branche sur [supabaseClientProvider] afin de rester testable : il suffit
/// d'`override` ce provider dans les tests.

/// Client Supabase partagé par toute l'application.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => SupabaseService.client,
);

/// Service d'upload (logos salon, photos avant/après clients).
final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(supabaseClientProvider)),
);

/// Flux des changements d'état d'authentification.
final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

/// Session courante (null si déconnecté).
final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  return authState?.session ?? ref.watch(supabaseClientProvider).auth.currentSession;
});

/// Identifiant de l'utilisateur connecté (null si déconnecté).
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentSessionProvider)?.user.id,
);
