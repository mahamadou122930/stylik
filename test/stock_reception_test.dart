import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/core/widgets/widgets.dart';
import 'package:stylik/features/inventory/domain/product.dart';
import 'package:stylik/features/inventory/presentation/inventory_providers.dart';
import 'package:stylik/features/inventory/presentation/stock_reception_page.dart';

/// Réception d'une livraison : on saisit des quantités au clavier, pas au
/// pas-à-pas, et on retrouve un produit dans une liste longue.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  Product product(String id, String name, {String brand = 'Marque'}) => Product(
    id: id,
    salonId: 'salon',
    name: name,
    brand: brand,
    category: 'Revente',
    stockQuantity: 2,
    alertThreshold: 1,
    unitSalePriceFcfa: 6000,
    unitCostFcfa: 2500,
  );

  Widget host() => ProviderScope(
    overrides: [
      productsProvider.overrideWith(
        (ref) async => [
          product('kera', 'Shampooing Kérastase'),
          product('masque', 'Masque réparateur'),
          product('gant', 'Gants jetables'),
        ],
      ),
    ],
    child: const MaterialApp(
      locale: Locale('fr', 'FR'),
      supportedLocales: [Locale('fr', 'FR'), Locale('en')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: StockReceptionPage(),
    ),
  );

  testWidgets('la quantité se saisit au clavier', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Trois produits, donc trois champs de quantité.
    expect(find.byType(TextField), findsNWidgets(4)); // 3 lignes + recherche

    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.pumpAndSettle();

    // 12 × 2 500 apparaît sur la ligne et dans le total.
    expect(find.textContaining(Formatters.fcfa(30000)), findsWidgets);
  });

  testWidgets('la recherche filtre la liste', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Masque réparateur'), findsOneWidget);

    // Sans accent : la recherche doit rester tolérante.
    await tester.enterText(find.byType(AppSearchField), 'kerastase');
    await tester.pumpAndSettle();

    expect(find.text('Shampooing Kérastase'), findsOneWidget);
    expect(find.text('Masque réparateur'), findsNothing);
    expect(find.text('Gants jetables'), findsNothing);
  });

  testWidgets('une ligne déjà saisie reste visible malgré le filtre', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // On saisit sur « Masque réparateur » (deuxième ligne).
    await tester.enterText(find.byType(TextField).at(2), '5');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(AppSearchField), 'gants');
    await tester.pumpAndSettle();

    // Sinon on croirait la saisie perdue en affinant sa recherche.
    expect(find.text('Masque réparateur'), findsOneWidget);
    expect(find.text('Gants jetables'), findsOneWidget);
    expect(find.text('Shampooing Kérastase'), findsNothing);
  });
}
