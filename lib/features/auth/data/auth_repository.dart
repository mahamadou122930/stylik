import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../domain/profile.dart';
import '../domain/user_role.dart';

/// Accès aux opérations d'authentification et au profil du personnel.
class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Inscription d'un membre du personnel.
  ///
  /// Le profil est créé côté base par un trigger sur `auth.users`, alimenté
  /// par les métadonnées passées ici.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? salonId,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role.value,
        'salon_id': ?salonId,
      },
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);

  /// Profil du personnel connecté (null si aucune session).
  Future<Profile?> fetchCurrentProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final data = await _client
        .from(SupabaseTables.profiles)
        .select()
        .eq('id', userId)
        .maybeSingle();

    return data == null ? null : Profile.fromMap(data);
  }

  Future<Profile> updateProfile(Profile profile) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .update(profile.toMap()..remove('id'))
        .eq('id', profile.id)
        .select()
        .single();

    return Profile.fromMap(data);
  }

  /// Vérifie le code PIN d'un membre (déverrouillage rapide en caisse).
  Future<bool> verifyPin({required String profileId, required String pin}) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .select('id')
        .eq('id', profileId)
        .eq('pin_code', pin)
        .maybeSingle();

    return data != null;
  }
}
