import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/core/constants/app_sizes.dart';
import 'package:stylik/core/widgets/widgets.dart';

/// Mise en page sur grand écran. Les maquettes sont dessinées pour un
/// téléphone, et plusieurs grilles y sont réglées en ratio largeur/hauteur :
/// étirées à la largeur d'un navigateur, leurs cartes deviennent hautes de
/// plusieurs centaines de pixels.
void main() {
  /// Fenêtre de navigateur en plein écran.
  void useDesktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget grid() => MaterialApp(
    home: AppScreen(
      title: 'Plus',
      largeTitle: true,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Le réglage réel de l'écran « Plus ».
        childAspectRatio: 1.15,
        children: const [
          AppCard(child: Text('Services')),
          AppCard(child: Text('Stock')),
        ],
      ),
    ),
  );

  testWidgets('le contenu reste dans une colonne de largeur raisonnable', (
    tester,
  ) async {
    useDesktop(tester);
    await tester.pumpWidget(grid());
    await tester.pumpAndSettle();

    // Sans plafond, chaque cellule ferait près de 950 px de large.
    final gridWidth = tester.getSize(find.byType(GridView)).width;
    expect(gridWidth, lessThanOrEqualTo(AppSizes.maxContentWidth));
  });

  testWidgets('une carte de grille ne prend pas toute la hauteur', (
    tester,
  ) async {
    useDesktop(tester);
    await tester.pumpWidget(grid());
    await tester.pumpAndSettle();

    // C'est le symptôme observé dans le navigateur : le titre de la carte
    // repoussé tout en bas d'un pavé haut de 800 px.
    final cardHeight = tester.getSize(find.byType(AppCard).first).height;
    expect(cardHeight, lessThan(400));
  });

  testWidgets('sur téléphone, la largeur reste celle de l\'écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(grid());
    await tester.pumpAndSettle();

    // Le plafond ne doit pas rétrécir un écran de téléphone : 360 px de large
    // moins les marges de l'écran.
    final gridWidth = tester.getSize(find.byType(GridView)).width;
    expect(gridWidth, 360 - AppSizes.screenPadding * 2);
  });
}
