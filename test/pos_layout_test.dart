import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/auth/presentation/auth_providers.dart';
import 'package:stylik/features/catalog/domain/salon_service.dart';
import 'package:stylik/features/clients/presentation/clients_providers.dart';
import 'package:stylik/features/inventory/domain/product.dart';
import 'package:stylik/features/pos/domain/payment_method.dart';
import 'package:stylik/features/pos/domain/ticket.dart';
import 'package:stylik/features/pos/presentation/pending_tickets_page.dart';
import 'package:stylik/features/pos/presentation/pos_page.dart';
import 'package:stylik/features/pos/presentation/pos_providers.dart';

/// Mise en page de la caisse. Les pieds d'écran alignent plusieurs boutons sur
/// une ligne, et `AppButton` s'étire à l'infini par défaut : sans contrainte,
/// la Row ne sait pas le placer et l'écran ne s'affiche plus du tout.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  /// Un écran de téléphone : c'est là que la place manque.
  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Widget host({
    required Widget page,
    List<SalonTransaction> pending = const [],
  }) => ProviderScope(
    overrides: [
      pendingTicketsProvider.overrideWith((ref) async => pending),
      clientsListProvider.overrideWith((ref) async => []),
      currentProfileProvider.overrideWith(
        (ref) async => const Profile(
          id: 'moi',
          salonId: 'salon',
          fullName: 'Fatoumata Coulibaly',
          role: UserRole.gerant,
        ),
      ),
    ],
    child: MaterialApp(locale: const Locale('fr', 'FR'), home: page),
  );

  testWidgets('la caisse s\'affiche avec un ticket en cours', (tester) async {
    usePhone(tester);

    await tester.pumpWidget(host(page: const PosPage()));
    final notifier = ProviderScope.containerOf(
      tester.element(find.byType(PosPage)),
    ).read(ticketProvider.notifier);

    notifier.addService(
      const SalonService(
        id: 's1',
        salonId: 'salon',
        name: 'Balayage',
        category: 'Couleur',
        durationMinutes: 90,
        priceFcfa: 42000,
      ),
    );
    notifier.addProduct(
      const Product(
        id: 'p1',
        salonId: 'salon',
        name: 'Masque réparateur',
        brand: 'Maison',
        category: 'Soin',
        stockQuantity: 4,
        alertThreshold: 1,
        unitSalePriceFcfa: 8500,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Les deux sections de la maquette, et le pied à deux boutons.
    expect(find.text('Prestations'), findsOneWidget);
    expect(find.text('Produits vendus'), findsOneWidget);
    expect(find.text('Attente'), findsOneWidget);
    expect(find.text('Payer'), findsOneWidget);
  });

  testWidgets('la caisse s\'affiche aussi avec un ticket vide', (tester) async {
    usePhone(tester);

    await tester.pumpWidget(host(page: const PosPage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ticket vide'), findsOneWidget);
  });

  testWidgets('l\'écran des tickets en attente s\'affiche', (tester) async {
    usePhone(tester);

    await tester.pumpWidget(
      host(
        page: const PendingTicketsPage(),
        pending: [
          SalonTransaction(
            id: 'a',
            salonId: 'salon',
            subtotalFcfa: 12000,
            discountFcfa: 0,
            totalAmountFcfa: 12000,
            paymentMethod: PaymentMethod.cash,
            status: TransactionStatus.draft,
            createdAt: DateTime.now(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Rappeler & encaisser'), findsOneWidget);
    expect(find.text(Formatters.fcfa(12000)), findsWidgets);
    // Sans fiche cliente, le ticket reste identifiable.
    expect(find.text('Client de passage'), findsOneWidget);
    expect(find.textContaining('en attente'), findsOneWidget);
  });

  group('sous-titre d\'une ardoise', () {
    Future<void> pumpWith(
      WidgetTester tester, {
      required Duration age,
      required List<TicketLine> lines,
      String? clientName,
    }) async {
      usePhone(tester);
      await tester.pumpWidget(
        host(
          page: const PendingTicketsPage(),
          pending: [
            SalonTransaction(
              id: 'a',
              salonId: 'salon',
              clientName: clientName,
              subtotalFcfa: 12000,
              discountFcfa: 0,
              totalAmountFcfa: 12000,
              paymentMethod: PaymentMethod.cash,
              status: TransactionStatus.draft,
              lines: lines,
              createdAt: DateTime.now().subtract(age),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    const service = TicketLine(
      refId: 's1',
      label: 'Coupe',
      unitPriceFcfa: 6000,
    );
    const product = TicketLine(
      refId: 'p1',
      label: 'Huile',
      unitPriceFcfa: 6000,
      isProduct: true,
    );

    testWidgets('une attente fraîche se compte en minutes', (tester) async {
      await pumpWith(
        tester,
        age: const Duration(minutes: 12),
        lines: const [service, service],
      );

      expect(find.text('2 prestations · en attente 12 min'), findsOneWidget);
    });

    testWidgets('au-delà d\'une heure, l\'unité change', (tester) async {
      // « en attente 180 min » se lit mal.
      await pumpWith(
        tester,
        age: const Duration(hours: 3),
        lines: const [service],
      );
      expect(find.textContaining('en attente 3 h'), findsOneWidget);
    });

    testWidgets('une ardoise de plusieurs jours se compte en jours', (
      tester,
    ) async {
      await pumpWith(
        tester,
        age: const Duration(days: 3),
        lines: const [service],
      );
      expect(find.textContaining('en attente 3 jours'), findsOneWidget);
    });

    testWidgets('un produit vendu n\'est pas une prestation', (tester) async {
      await pumpWith(
        tester,
        age: const Duration(minutes: 5),
        lines: const [service, product],
      );

      expect(find.textContaining('2 articles'), findsOneWidget);
      expect(find.textContaining('prestations'), findsNothing);
    });
  });
}
