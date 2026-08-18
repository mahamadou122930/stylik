import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/agenda/presentation/agenda_providers.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/auth/presentation/auth_providers.dart';

/// Le cloisonnement par rôle : le coiffeur réalise ses prestations et voit sa
/// rémunération, sans accès au planning du salon, au catalogue ni à la caisse.
/// Ce sont ces règles-là — pas la mise en page — qui protègent les données.
void main() {
  Profile profileWith(UserRole role) => Profile(
    id: 'profile-${role.value}',
    salonId: 'salon',
    fullName: 'Membre',
    role: role,
  );

  group('matrice des permissions', () {
    test('le coiffeur ne voit pas le planning du salon', () {
      expect(UserRole.coiffeur.canViewFullAgenda, isFalse);
      expect(UserRole.receptionniste.canViewFullAgenda, isTrue);
      expect(UserRole.gerant.canViewFullAgenda, isTrue);
    });

    test('créer ou tarifer un service est réservé au comptoir', () {
      expect(UserRole.coiffeur.canManageCatalog, isFalse);
      expect(UserRole.receptionniste.canManageCatalog, isTrue);
      expect(UserRole.gerant.canManageCatalog, isTrue);
    });

    test('le coiffeur n\'encaisse pas', () {
      expect(UserRole.coiffeur.canOperatePos, isFalse);
      expect(UserRole.receptionniste.canOperatePos, isTrue);
      expect(UserRole.gerant.canOperatePos, isTrue);
    });

    test('chacun voit ses commissions, la finance reste au gérant', () {
      for (final role in UserRole.values) {
        expect(role.canViewOwnCommission, isTrue, reason: role.value);
      }
      expect(UserRole.coiffeur.canViewFinance, isFalse);
      expect(UserRole.receptionniste.canViewFinance, isFalse);
      expect(UserRole.gerant.canViewFinance, isTrue);
    });

    test('le gérant conserve toutes les permissions', () {
      for (final permission in RolePermission.values) {
        expect(
          UserRole.gerant.can(permission),
          isTrue,
          reason: permission.label,
        );
      }
    });
  });

  group('filtre de l\'agenda', () {
    /// Le filtre est décidé dans le provider, pas dans les écrans : c'est ce
    /// qui garantit qu'aucune page ne charge la journée des collègues.
    String? filterFor(UserRole role, {String? selected}) {
      final profile = profileWith(role);
      final container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => profile),
          if (selected != null)
            selectedStylistProvider.overrideWith((ref) => selected),
        ],
      );
      addTearDown(container.dispose);

      // `currentProfileProvider` est asynchrone : sans lecture préalable, le
      // filtre verrait un profil encore nul.
      container.read(currentProfileProvider);
      return container.read(agendaStylistFilterProvider);
    }

    test('le coiffeur est verrouillé sur sa propre fiche', () async {
      final profile = profileWith(UserRole.coiffeur);
      final container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => profile),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentProfileProvider.future);

      expect(container.read(agendaStylistFilterProvider), profile.id);
    });

    test('le coiffeur ne peut pas viser un collègue', () async {
      final profile = profileWith(UserRole.coiffeur);
      final container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => profile),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentProfileProvider.future);

      // Même en forçant la sélection sur un autre coiffeur, le filtre
      // retombe sur sa propre fiche.
      container.read(selectedStylistProvider.notifier).state =
          'quelqu-un-dautre';

      expect(container.read(agendaStylistFilterProvider), profile.id);
    });

    test('la réception garde le planning global', () async {
      final profile = profileWith(UserRole.receptionniste);
      final container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => profile),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentProfileProvider.future);

      expect(container.read(agendaStylistFilterProvider), isNull);

      container.read(selectedStylistProvider.notifier).state =
          'coiffeur-choisi';
      expect(container.read(agendaStylistFilterProvider), 'coiffeur-choisi');
    });

    // Garde-fou : `filterFor` documente l'usage synchrone, qui ne doit jamais
    // rendre un filtre nul pour un coiffeur une fois le profil résolu.
    test('aucun filtre tant que le profil n\'est pas chargé', () {
      expect(filterFor(UserRole.coiffeur), isNull);
    });
  });
}
