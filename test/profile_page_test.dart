import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/auth/presentation/auth_providers.dart';
import 'package:stylik/features/auth/presentation/profile_page.dart';
import 'package:stylik/features/settings/domain/salon.dart';
import 'package:stylik/features/settings/presentation/settings_providers.dart';

/// « Mon profil » montre l'identité de la personne connectée. Tant qu'elle
/// n'est pas lue, il ne doit rien inventer : une identité affichée est une
/// identité qu'on croit sienne.
void main() {
  Profile profile({String name = 'Mahamadou Santara', String? email}) =>
      Profile(
        id: 'moi',
        salonId: 'salon',
        fullName: name,
        role: UserRole.gerant,
        email: email,
      );

  Widget host({required Future<Profile?> Function() onProfile, Salon? salon}) =>
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) => onProfile()),
          currentSalonProvider.overrideWith((ref) async => salon),
        ],
        child: const MaterialApp(
          locale: Locale('fr', 'FR'),
          home: ProfilePage(),
        ),
      );

  Salon salonNamed(String name) =>
      Salon(id: 'salon', name: name, phone: '70000000', address: 'Bamako');

  testWidgets('le profil chargé s\'affiche avec son rôle et son salon', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        onProfile: () async => profile(email: 'santara@exemple.ml'),
        salon: salonNamed('Salon Kadiatou'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mahamadou Santara'), findsOneWidget);
    expect(find.text('santara@exemple.ml'), findsOneWidget);
    expect(find.text('Gérant · Salon Kadiatou'), findsOneWidget);
  });

  testWidgets('pendant le chargement, aucune identité n\'est inventée', (
    tester,
  ) async {
    await tester.pumpWidget(
      // Une attente qui ne se resout jamais, plutot qu'un `Future.delayed` :
      // celui-ci laisserait un minuteur en vie apres la fin du test.
      host(onProfile: () => Completer<Profile?>().future),
    );
    await tester.pump();

    // Le repli codé en dur affichait « Fatoumata Traoré » et une adresse
    // d'exemple : hors ligne, on voyait l'identité de quelqu'un d'autre.
    expect(find.textContaining('Fatoumata'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('un profil introuvable est signalé, pas maquillé', (
    tester,
  ) async {
    await tester.pumpWidget(host(onProfile: () async => null));
    await tester.pumpAndSettle();

    expect(find.text('Profil introuvable pour ce compte.'), findsOneWidget);
    expect(find.textContaining('Fatoumata'), findsNothing);
  });

  testWidgets('sans salon chargé, le rôle s\'affiche seul', (tester) async {
    await tester.pumpWidget(host(onProfile: () async => profile()));
    await tester.pumpAndSettle();

    // « Gérant · L'Atelier Coiffure » nommait un salon qui n'existe pas.
    expect(find.text('Gérant'), findsOneWidget);
    expect(find.textContaining('Atelier'), findsNothing);
  });

  testWidgets('sans email, la ligne est omise plutôt que remplie', (
    tester,
  ) async {
    // Un compte créé par le gérant pour un coiffeur n'a pas toujours d'email.
    await tester.pumpWidget(host(onProfile: () async => profile()));
    await tester.pumpAndSettle();

    expect(find.text('Mahamadou Santara'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });
}
