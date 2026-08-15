import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/core/widgets/app_charts.dart';

/// Le graphe de la semaine sur l'accueil. Ses barres sont sélectionnables :
/// une journée sans recette ne mesure que six pixels de haut, donc la zone
/// tactile doit couvrir toute la colonne, sinon le jour est invisible au doigt.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: child)),
        ),
      );

  testWidgets('sans callback, les barres ne réagissent pas', (tester) async {
    await tester.pumpWidget(
      host(
        const AppBarChart(
          slices: [
            ChartSlice(label: 'L', value: 0),
            ChartSlice(label: 'M', value: 5500),
          ],
        ),
      ),
    );

    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('chaque colonne remonte son index', (tester) async {
    final taps = <int>[];

    await tester.pumpWidget(
      host(
        AppBarChart(
          onSliceTap: taps.add,
          slices: const [
            ChartSlice(label: 'L', value: 0),
            ChartSlice(label: 'M', value: 0),
            ChartSlice(label: 'M', value: 0),
            ChartSlice(label: 'J', value: 0),
            ChartSlice(label: 'V', value: 5500),
            ChartSlice(label: 'S', value: 0),
            ChartSlice(label: 'D', value: 0),
          ],
        ),
      ),
    );

    // La barre haute.
    await tester.tap(find.text('V'));
    // Un jour à zéro : c'est le cas qui échouait si la zone tactile se
    // limitait à la barre elle-même.
    await tester.tap(find.text('L'));
    await tester.tap(find.text('D'));

    expect(taps, [4, 0, 6]);
  });

  testWidgets('une semaine entièrement vide reste cliquable', (tester) async {
    final taps = <int>[];

    await tester.pumpWidget(
      host(
        AppBarChart(
          onSliceTap: taps.add,
          slices: const [
            ChartSlice(label: 'L', value: 0),
            ChartSlice(label: 'M', value: 0),
          ],
        ),
      ),
    );

    // `maxValue` vaut zéro : le calcul du ratio ne doit pas produire de NaN
    // et emporter la mise en page avec lui.
    await tester.tap(find.text('M'));
    expect(taps, [1]);
  });
}
