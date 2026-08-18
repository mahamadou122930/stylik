import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/core/theme/app_theme.dart';
import 'package:stylik/core/widgets/widgets.dart';

void main() {
  testWidgets('AppButton affiche son libellé et réagit au tap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppButton(label: 'Encaisser', onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Encaisser'), findsOneWidget);

    await tester.tap(find.text('Encaisser'));
    expect(tapped, isTrue);
  });

  testWidgets('AppEmptyState affiche titre et message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: AppEmptyState(
            title: 'Aucun rendez-vous',
            message: 'Le planning de cette journée est vide.',
          ),
        ),
      ),
    );

    expect(find.text('Aucun rendez-vous'), findsOneWidget);
    expect(find.text('Le planning de cette journée est vide.'), findsOneWidget);
  });
}
