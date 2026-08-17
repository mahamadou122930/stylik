import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/core/constants/app_colors.dart';
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

  /// Couleur reellement peinte par chaque barre.
  List<Color?> barColors(WidgetTester tester) => tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => (c.decoration as BoxDecoration?)?.color)
      .toList();

  group('mise en avant', () {
    testWidgets('par defaut, la barre la plus haute ressort', (tester) async {
      await tester.pumpWidget(
        host(
          const AppBarChart(
            slices: [
              ChartSlice(label: 'A', value: 100),
              ChartSlice(label: 'B', value: 900),
              ChartSlice(label: 'C', value: 300),
            ],
          ),
        ),
      );

      // `highlightMax` vaut true par defaut : c'est le comportement d'origine
      // des graphes que je n'ai pas touches.
      expect(barColors(tester).where((c) => c == AppColors.accent).length, 1);
    });

    testWidgets('highlightIndex met en avant par position', (tester) async {
      await tester.pumpWidget(
        host(
          const AppBarChart(
            highlightMax: false,
            highlightIndex: 0,
            slices: [
              ChartSlice(label: 'A', value: 100),
              ChartSlice(label: 'B', value: 900),
            ],
          ),
        ),
      );

      // Le jour courant n'est pas forcement le plus haut : c'est l'usage de
      // la carte « Semaine en cours ».
      final colors = barColors(tester);
      expect(colors.where((c) => c == AppColors.accent).length, 1);
      expect(colors, contains(AppColors.accent));
    });

    testWidgets('une couleur de tranche prime sur la mise en avant',
        (tester) async {
      await tester.pumpWidget(
        host(
          const AppBarChart(
            slices: [
              ChartSlice(label: 'A', value: 0, color: AppColors.toggleOff),
              ChartSlice(label: 'B', value: 900),
            ],
          ),
        ),
      );

      // Un jour sans encaissement reste en piste neutre.
      expect(barColors(tester).contains(AppColors.toggleOff), isTrue);
    });

    testWidgets('le tap ne change pas les couleurs rendues', (tester) async {
      Widget chart(bool tappable) => AppBarChart(
            onSliceTap: tappable ? (_) {} : null,
            slices: const [
              ChartSlice(label: 'A', value: 100),
              ChartSlice(label: 'B', value: 900),
            ],
          );

      await tester.pumpWidget(host(chart(false)));
      final sansTap = barColors(tester);

      await tester.pumpWidget(host(chart(true)));
      final avecTap = barColors(tester);

      // Rendre les barres cliquables ne devait rien changer a l'affichage.
      expect(avecTap, sansTap);
    });
  });

  group('autres graphes', () {
    testWidgets('l anneau de repartition se rend', (tester) async {
      await tester.pumpWidget(
        host(
          const AppDonutChart(
            slices: [
              ChartSlice(label: 'Coupe', value: 60),
              ChartSlice(label: 'Couleur', value: 40),
            ],
          ),
        ),
      );

      expect(find.text('Coupe'), findsOneWidget);
      expect(find.text('Couleur'), findsOneWidget);
    });

    testWidgets('le bloc a deux colonnes se rend', (tester) async {
      await tester.pumpWidget(
        host(
          const AppSplitMetrics(
            entries: [
              (value: '2 104 000 F', label: 'CA genere', color: null),
              (value: '322 000 F', label: 'Commission', color: null),
            ],
          ),
        ),
      );

      expect(find.text('CA genere'), findsOneWidget);
      expect(find.text('322 000 F'), findsOneWidget);
    });
  });
}
