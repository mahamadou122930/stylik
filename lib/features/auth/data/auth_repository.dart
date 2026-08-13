import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../domain/profile.dart';
import '../domain/salon_invite.dart';
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

  /// Salon désigné par un code d'invitation, ou `null` si le code n'existe pas.
  ///
  /// Passe par la RPC `salon_by_invite_code`, ouverte à `anon` : la personne
  /// n'a pas encore de session quand elle saisit son code.
  Future<SalonInvite?> findSalonByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.length != inviteCodeLength) return null;

    final rows = await _client.rpc<List<dynamic>>(
      'salon_by_invite_code',
      params: {'p_code': normalized},
    );

    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;

    return SalonInvite(
      code: normalized,
      salonId: row['id'] as String,
      salonName: (row['name'] as String?) ?? '',
    );
  }

  /// Inscription d'un employé sur un salon existant.
  ///
  /// Seul le code part vers le serveur : c'est lui qui désigne le salon, et le
  /// rôle vient de la fiche pré-créée par le gérant — rien de tout cela n'est
  /// décidé côté client.
  Future<AuthResponse> joinSalon({
    required String code,
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'join_code': code.trim().toUpperCase(),
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

    // Le profil est retrouvé par `user_id`, pas par `id` : depuis la migration
    // `20260807_standalone_staff_profiles`, un profil créé par le gérant a son
    // propre identifiant et n'est rattaché à un compte qu'à l'inscription.
    final data = await _client
        .from(SupabaseTables.profiles)
        .select(Profile.columns)
        .eq('user_id', userId)
        .maybeSingle();

    return data == null ? null : Profile.fromMap(data);
  }

  Future<Profile> updateProfile(Profile profile) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .update(profile.toMap()..remove('id'))
        .eq('id', profile.id)
        .select(Profile.columns)
        .single();

    return Profile.fromMap(data);
  }

  /// Vérifie le code PIN d'un membre (déverrouillage rapide en caisse).
  ///
  /// Passe uniquement par la RPC `verify_pin` : `pin_code` n'est jamais lu
  /// côté client. Une panne de la RPC doit remonter à l'appelant — se rabattre
  /// sur une comparaison en clair rendrait le durcissement contournable et
  /// masquerait une RPC absente en production.
  Future<bool> verifyPin({required String profileId, required String pin}) {
    return _client.rpc<bool>(
      'verify_pin',
      params: {
        'p_profile_id': profileId,
        'p_pin': pin,
      },
    );
  }
}
