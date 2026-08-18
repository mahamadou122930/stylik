import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/core/constants/app_colors.dart';
import 'package:stylik/core/widgets/widgets.dart';

/// `AppIconButton` retombe sur un retour arrière quand aucune action n'est
/// donnée — pratique pour les flèches d'en-tête, piège partout ailleurs :
/// un bouton passé à `onTap: null` pour le désactiver quittait l'écran.
void main() {
  Widget host(Widget button) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(body: Center(child: button)),
                ),
              ),
              child: const Text('ouvrir'),
            );
          },
        ),
      ),
    ),
  );

  testWidgets('sans action, le bouton revient en arrière', (tester) async {
    await tester.pumpWidget(host(const AppIconButton(icon: Icons.close)));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(AppIconButton), findsOneWidget);

    await tester.tap(find.byType(AppIconButton));
    await tester.pumpAndSettle();

    // L'écran poussé est refermé : c'est le comportement des flèches d'en-tête.
    expect(find.text('ouvrir'), findsOneWidget);
  });

  testWidgets('désactivé, il ne fait rien du tout', (tester) async {
    await tester.pumpWidget(
      host(const AppIconButton(icon: Icons.chevron_right, enabled: false)),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppIconButton));
    await tester.pumpAndSettle();

    // Surtout : il ne quitte pas l'écran.
    expect(find.byType(AppIconButton), findsOneWidget);
    expect(find.text('ouvrir'), findsNothing);
  });

  testWidgets('désactivé, il est grisé', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppIconButton(icon: Icons.chevron_right, enabled: false),
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, AppColors.textFaint);
  });

  testWidgets('une action explicite est bien appelée', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppIconButton(icon: Icons.chevron_left, onTap: () => taps++),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppIconButton));
    expect(taps, 1);
  });
}
