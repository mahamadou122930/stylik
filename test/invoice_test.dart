import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/pos/domain/payment_method.dart';
import 'package:stylik/features/pos/domain/ticket.dart';
import 'package:stylik/features/pos/data/invoice_pdf.dart';
import 'package:stylik/features/pos/presentation/pos_providers.dart';
import 'package:stylik/features/pos/presentation/receipt_page.dart';
import 'package:stylik/features/settings/domain/salon.dart';
import 'package:stylik/features/settings/presentation/settings_providers.dart';

/// Découpage du reçu. Une vente de produit est une marchandise, pas un service
/// rendu : le client doit retrouver ce qu'il emporte sur une ligne distincte,
/// et pouvoir refaire le calcul quand il en achète plusieurs.
void main() {
  setUpAll(() {
    // `rootBundle` sert à charger les polices de la facture.
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  TicketLine line({
    required String label,
    required int price,
    int quantity = 1,
    bool isProduct = false,
    String? category,
  }) => TicketLine(
    refId: label,
    label: label,
    unitPriceFcfa: price,
    quantity: quantity,
    isProduct: isProduct,
    category: category,
  );

  /// Rend le véritable `ReceiptPage`, pas une reconstitution : c'est son
  /// découpage en sections qu'on veut vérifier.
  Widget host(SalonTransaction transaction) => ProviderScope(
    overrides: [
      lastTransactionProvider.overrideWith((ref) => transaction),
      currentSalonProvider.overrideWith(
        (ref) async => const Salon(
          id: 'salon',
          name: 'L\'Atelier Coiffure',
          phone: '+223 76 12 34 56',
          address: 'Hamdallaye ACI 2000, Bamako',
        ),
      ),
    ],
    child: const MaterialApp(locale: Locale('fr', 'FR'), home: ReceiptPage()),
  );

  SalonTransaction transaction(
    List<TicketLine> lines, {
    String? clientName,
    String? clientPhone,
    int? invoiceSeq,
  }) {
    final subtotal = lines.fold<int>(
      0,
      (sum, l) => sum + l.unitPriceFcfa * l.quantity,
    );
    return SalonTransaction(
      id: 'tx-0001',
      salonId: 'salon',
      subtotalFcfa: subtotal,
      discountFcfa: 0,
      totalAmountFcfa: subtotal,
      paymentMethod: PaymentMethod.cash,
      status: TransactionStatus.paid,
      createdAt: DateTime.now(),
      lines: lines,
      clientName: clientName,
      clientPhone: clientPhone,
      invoiceSeq: invoiceSeq,
    );
  }

  test('le total d\'une ligne multiplie bien le prix unitaire', () {
    final shampooing = line(
      label: 'Shampooing',
      price: 6000,
      quantity: 3,
      isProduct: true,
    );

    // C'est ce que le reçu doit permettre de vérifier : 3 × 6 000 = 18 000.
    expect(shampooing.unitPriceFcfa, 6000);
    expect(shampooing.totalFcfa, 18000);
  });

  test('un ticket mixte distingue prestations et produits', () {
    final tx = transaction([
      line(label: 'Coupe homme', price: 15000),
      line(label: 'Shampooing', price: 6000, quantity: 2, isProduct: true),
    ]);

    final services = tx.lines.where((l) => !l.isProduct).toList();
    final products = tx.lines.where((l) => l.isProduct).toList();

    expect(services.map((l) => l.label), ['Coupe homme']);
    expect(products.map((l) => l.label), ['Shampooing']);
    expect(tx.subtotalFcfa, 27000);
  });

  test('une vente de produit seule reste un ticket valide', () {
    final tx = transaction([
      line(label: 'Masque nutritif', price: 12000, isProduct: true),
    ]);

    expect(tx.lines.every((l) => l.isProduct), isTrue);
    expect(tx.totalAmountFcfa, 12000);
  });

  testWidgets('la facture porte émetteur, numéro, destinataire et total', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        transaction(
          [
            line(
              label: 'Shampooing pro 1 L',
              price: 15000,
              isProduct: true,
              category: 'Kérastase',
            ),
            line(
              label: 'Masque réparateur',
              price: 12000,
              quantity: 2,
              isProduct: true,
              category: 'Kérastase',
            ),
          ],
          clientName: 'Awa Traoré',
          clientPhone: '+223 76 12 34 56',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Facture'), findsWidgets);
    expect(find.text('L\'Atelier Coiffure'), findsOneWidget);
    expect(find.text('Facturé à'), findsOneWidget);
    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(find.text('+223 76 12 34 56'), findsOneWidget);

    // Marque puis quantité, comme sur la maquette.
    expect(find.text('Kérastase · x1'), findsOneWidget);
    expect(find.text('Kérastase · x2'), findsOneWidget);

    // 15 000 + 2 × 12 000.
    expect(find.text(Formatters.fcfa(39000)), findsOneWidget);
    expect(find.textContaining('Payé · Espèces'), findsOneWidget);
  });

  testWidgets('sans client rattaché, le bloc « Facturé à » disparaît', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(transaction([line(label: 'Coupe homme', price: 15000)])),
    );
    await tester.pumpAndSettle();

    // Une vente au comptoir n'a pas toujours de fiche client : mieux vaut
    // omettre la section qu'afficher un destinataire vide.
    expect(find.text('Facturé à'), findsNothing);
    expect(find.text('Coupe homme'), findsOneWidget);
  });

  group('numéro de facture', () {
    test('utilise le rang attribué par la base quand il existe', () {
      final tx = transaction([
        line(label: 'Coupe', price: 5000),
      ], invoiceSeq: 261);

      expect(tx.invoiceNumber, 'FA-${DateTime.now().year}-0261');
    });

    test('la suite reste continue et ordonnée', () {
      final numbers = [1, 2, 3, 10, 1000]
          .map(
            (seq) => transaction([
              line(label: 'Coupe', price: 5000),
            ], invoiceSeq: seq).invoiceNumber,
          )
          .toList();

      final year = DateTime.now().year;
      expect(numbers, [
        'FA-$year-0001',
        'FA-$year-0002',
        'FA-$year-0003',
        'FA-$year-0010',
        'FA-$year-1000',
      ]);
      // Le remplissage à quatre chiffres garantit que l'ordre alphabétique
      // suit l'ordre d'émission.
      final sorted = [...numbers]..sort();
      expect(sorted, numbers);
    });

    test('sans rang en base, le repli reste stable et bien formé', () {
      final tx = transaction([line(label: 'Coupe', price: 5000)]);

      expect(tx.invoiceNumber, matches(r'^FA-\d{4}-\d{4}$'));
      // Deux lectures du même ticket donnent le même numéro.
      expect(tx.invoiceNumber, tx.invoiceNumber);
    });

    test('le client n\'envoie jamais le numéro à la base', () {
      final tx = transaction([
        line(label: 'Coupe', price: 5000),
      ], invoiceSeq: 42);

      // Le rang est posé par le déclencheur : le laisser partir depuis l'app
      // permettrait de réémettre un numéro déjà utilisé.
      expect(tx.toMap().containsKey('invoice_seq'), isFalse);
    });
  });

  group('document PDF', () {
    test('produit un fichier PDF valide', () async {
      final bytes = await InvoicePdf.build(
        transaction: transaction(
          [
            line(
              label: 'Shampooing pro 1 L',
              price: 15000,
              isProduct: true,
              category: 'Kérastase',
            ),
          ],
          clientName: 'Awa Traoré',
          invoiceSeq: 261,
        ),
        salon: const Salon(
          id: 'salon',
          name: 'L\'Atelier Coiffure',
          phone: '+223 76 12 34 56',
          address: 'Hamdallaye ACI 2000, Bamako',
        ),
      );

      // Un PDF commence par %PDF- : sans ce controle, une generation vide
      // passerait pour un succes.
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('un logo injoignable ne bloque pas l emission', () async {
      final bytes = await InvoicePdf.build(
        transaction: transaction([line(label: 'Coupe', price: 5000)]),
        salon: const Salon(
          id: 'salon',
          name: 'Salon test',
          phone: '',
          address: '',
          // URL volontairement morte : une facture doit sortir sans logo
          // plutot que pas du tout.
          logoUrl: 'https://exemple.invalid/logo.png',
        ),
      );

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('se genere sans salon ni client rattaches', () async {
      final bytes = await InvoicePdf.build(
        transaction: transaction([line(label: 'Coupe', price: 5000)]),
      );

      // Une vente au comptoir sans fiche client ne doit pas faire echouer
      // l emission du document.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
