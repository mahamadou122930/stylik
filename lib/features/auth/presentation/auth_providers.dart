import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/auth_repository.dart';
import '../domain/profile.dart';
import '../domain/registration_draft.dart';
import '../domain/user_role.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Profil du membre connecté. Rechargé à chaque changement de session.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(authRepositoryProvider).fetchCurrentProfile();
});

/// Rôle courant — sert au filtrage des écrans et des permissions.
final currentRoleProvider = Provider<UserRole?>(
  (ref) => ref.watch(currentProfileProvider).valueOrNull?.role,
);

/// Salon auquel le membre connecté est rattaché.
final currentSalonIdProvider = Provider<String?>(
  (ref) => ref.watch(currentProfileProvider).valueOrNull?.salonId,
);

/// Contrôleur des actions d'authentification (connexion, inscription…).
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  AuthRepository get _repository => _ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      await _repository.signIn(email: email, password: password);
      _ref.invalidate(currentProfileProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? salonId,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        salonId: salonId,
      );
      _ref.invalidate(currentProfileProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  /// Inscription complète du parcours 1.3 → 1.4 : le salon est créé, puis le
  /// compte du gérant y est rattaché, puis le logo est téléversé s'il y en a un.
  ///
  /// Le logo est le seul maillon non bloquant : un échec de téléversement ne
  /// doit pas invalider un salon et un compte déjà créés.
  Future<bool> registerSalon(RegistrationDraft draft) async {
    state = const AsyncLoading();
    try {
      final settings = _ref.read(settingsRepositoryProvider);
      final salon = await settings.create(
        name: draft.salonName,
        phone: draft.salonPhone,
        address: draft.salonAddress,
      );

      await _repository.signUp(
        email: draft.email,
        password: draft.password,
        fullName: draft.fullName,
        role: draft.role,
        salonId: salon.id,
      );

      if (draft.logo != null) {
        try {
          await settings.updateLogo(salon: salon, file: draft.logo!);
        } catch (_) {
          // Logo optionnel : modifiable plus tard depuis « Mon salon ».
        }
      }

      _ref.invalidate(currentProfileProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _ref.invalidate(currentProfileProvider);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
  AuthController.new,
);
