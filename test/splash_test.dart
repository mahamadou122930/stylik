import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/core/constants/app_colors.dart';
import 'package:stylik/features/auth/presentation/splash_page.dart';

/// 1.0 — Splash. C'est le premier écran que voit un utilisateur : il porte le
/// nom du produit et le vert de marque, et il doit rester assez longtemps pour
/// être vu.
void main() {
  Widget host() =>
      const MaterialApp(locale: Locale('fr', 'FR'), home: SplashPage());

  testWidgets('le nom du produit s\'affiche', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    // Le produit s'appelle Stylik. « L'Atelier » était le nom d'un salon
    // d'exemple, resté par erreur dans l'identité de l'application.
    expect(find.text('Stylik'), findsOneWidget);
    expect(find.textContaining('Atelier'), findsNothing);
  });

  testWidgets('l\'attente est annoncée', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Chargement…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('le fond porte le dégradé de marque', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    // Le même que l'écran Bienvenue qui suit : l'enchaînement doit se lire
    // comme un seul écran qui se remplit.
    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SplashPage),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.gradient, AppColors.welcomeGradient);
  });

  test('la durée minimale est perceptible sans faire attendre', () {
    // Sous ~500 ms l'écran n'est qu'un clignotement ; au-delà d'une seconde,
    // il retarde une application qui était prête.
    expect(
      SplashPage.minimumDuration.inMilliseconds,
      inInclusiveRange(500, 1200),
    );
  });
}
