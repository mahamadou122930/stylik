import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Point d'entrée unique vers Supabase.
///
/// Les clés sont injectées au build via `--dart-define` :
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
/// ```
/// Aucune clé ne doit être commitée dans le dépôt.
abstract final class SupabaseService {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? const String.fromEnvironment('SUPABASE_URL');
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool _initialized = false;

  /// Initialise le SDK. À appeler une seule fois, avant `runApp`.
  static Future<void> initialize() async {
    if (_initialized) return;

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY manquants. '
        'Lancez l\'application avec --dart-define pour les fournir.',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      // `publishableKey` remplace `anonKey`, déprécié depuis supabase_flutter 2.15.
      publishableKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        // La session est persistée localement : le personnel reste connecté
        // entre deux ouvertures de l'application.
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.error,
      ),
    );

    _initialized = true;
  }

  /// Client Supabase courant.
  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static SupabaseStorageClient get storage => client.storage;

  /// Utilisateur authentifié, ou `null`.
  static User? get currentUser => auth.currentUser;

  static String? get currentUserId => currentUser?.id;

  static bool get isSignedIn => currentUser != null;

  /// Flux des changements d'état d'authentification (login, logout, refresh).
  static Stream<AuthState> get authStateChanges => auth.onAuthStateChange;
}
