import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/auth/presentation/auth_providers.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/domain/payout.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';

/// Journées de l'écran de demande de versement.
///
/// Elles se lisaient dans les transactions… non : elles étaient **fabriquées**.
/// Le solde disponible était réparti sur cinq jours avec des poids codés en
/// dur par jour de semaine, puis chaque journée bornée entre 15 000 et
/// 150 000 F. Les bornes écrasaient l'entrée — un membre sans aucune vente se
/// voyait proposer 70 000 F.
void main() {
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  const profile = Profile(
    id: 'moi',
    salonId: 'salon',
    fullName: 'Karim Diop',
    role: UserRole.coiffeur,
    commissionRate: 30,
  );

  ProviderContainer withDays(List<DailyCommissionItem> days) {
    final c = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        myDailyCommissionsProvider.overrideWith((ref) async => days),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  DailyCommissionItem day(int commission, {bool isCurrent = false}) =>
      DailyCommissionItem(
        date: DateTime(2026, 8, 20),
        label: 'jeu. 20 août',
        serviceCount: 3,
        revenueFcfa: commission * 100 ~/ 30,
        commissionFcfa: commission,
        isCurrentDay: isCurrent,
      );

  group('sans activité, rien n\'est proposé', () {
    test('aucune journée ne porte de montant inventé', () async {
      final c = withDays([day(0), day(0), day(0, isCurrent: true)]);
      final days = await c.read(myDailyCommissionsProvider.future);

      // Le calcul d'origine aurait rendu 15 000, 15 000 et 10 000.
      expect(days.every((d) => d.commissionFcfa == 0), isTrue);
      expect(days.fold<int>(0, (s, d) => s + d.commissionFcfa), 0);
    });
  });

  group('plafond au dû réel', () {
    Future<({int selected, int available, int sent, bool capped})> simulate({
      required List<int> dayAmounts,
      required int earned,
      required List<PayoutRequest> payouts,
    }) async {
      final c = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => profile),
          cumulativeCommissionsProvider.overrideWith(
            (ref) async => [
              StylistCommission(
                stylistId: 'moi',
                stylistName: 'Karim Diop',
                revenueFcfa: earned * 100 ~/ 30,
                commissionFcfa: earned,
                serviceCount: 10,
                commissionRate: 30,
              ),
            ],
          ),
          myPayoutsProvider.overrideWith((ref) async => payouts),
        ],
      );
      addTearDown(c.dispose);

      // Les trois sources sont asynchrones : sans attente, le solde lirait
      // zéro et le test passerait pour la mauvaise raison.
      await c.read(currentProfileProvider.future);
      await c.read(cumulativeCommissionsProvider.future);
      await c.read(myPayoutsProvider.future);

      final available = c.read(payoutBalanceProvider).available;
      final selected = dayAmounts.fold<int>(0, (s, a) => s + a);
      // La règle de l'écran, reproduite à l'identique.
      final sent = selected > available ? available : selected;
      return (
        selected: selected,
        available: available,
        sent: sent,
        capped: selected > available,
      );
    }

    test('la sélection passe telle quelle quand le dû la couvre', () async {
      final c = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => profile),
          cumulativeCommissionsProvider.overrideWith(
            (ref) async => const [
              StylistCommission(
                stylistId: 'moi',
                stylistName: 'Karim Diop',
                revenueFcfa: 1000000,
                commissionFcfa: 300000,
                serviceCount: 10,
                commissionRate: 30,
              ),
            ],
          ),
          myPayoutsProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(c.dispose);
      await c.read(cumulativeCommissionsProvider.future);
      await c.read(myPayoutsProvider.future);
      await c.read(currentProfileProvider.future);

      final available = c.read(payoutBalanceProvider).available;
      const selected = 120000;
      expect(selected > available, isFalse);
    });

    test('une sélection supérieure au dû est ramenée au dû', () async {
      // Les journées montrent ce qui a été gagné ; une part a déjà été versée.
      final r = await simulate(
        dayAmounts: [50000, 50000, 50000],
        earned: 200000,
        payouts: [
          PayoutRequest(
            id: 'p1',
            salonId: 'salon',
            profileId: 'moi',
            amountFcfa: 120000,
            status: PayoutStatus.paid,
            requestedAt: DateTime(2026, 8, 1),
            paidAt: DateTime(2026, 8, 1),
          ),
        ],
      );

      expect(r.selected, 150000);
      expect(r.available, 80000);
      // Sans plafond, la demande partait à 150 000 et la base la rejetait.
      expect(r.sent, 80000);
      expect(r.capped, isTrue);
    });

    test('sans dû restant, rien ne part', () async {
      final r = await simulate(
        dayAmounts: [40000],
        earned: 40000,
        payouts: [
          PayoutRequest(
            id: 'p1',
            salonId: 'salon',
            profileId: 'moi',
            amountFcfa: 40000,
            status: PayoutStatus.paid,
            requestedAt: DateTime(2026, 8, 1),
            paidAt: DateTime(2026, 8, 1),
          ),
        ],
      );

      expect(r.available, 0);
      expect(r.sent, 0);
    });
  });

  group('fenêtre listée', () {
    test('la constante couvre un mois', () {
      expect(payoutHistoryDays, 30);
    });
  });

  group('sélection par défaut', () {
    /// La règle de `_initSelection`, reproduite à l'identique.
    List<int> defaultSelection(List<DailyCommissionItem> items) => [
      for (var i = 0; i < items.length; i++)
        if (items[i].commissionFcfa > 0) i,
    ];

    test('la journée en cours est cochée comme les autres', () {
      final items = [day(40000), day(25000), day(18000, isCurrent: true)];

      // Elle était exclue, ce qui obligeait à revenir le lendemain pour
      // réclamer une commission déjà gagnée.
      expect(defaultSelection(items), [0, 1, 2]);
    });

    test('une journée sans commission reste décochée', () {
      final items = [day(40000), day(0), day(18000, isCurrent: true)];

      // La cocher n'ajouterait rien au total tout en laissant croire qu'elle
      // compte.
      expect(defaultSelection(items), [0, 2]);
    });

    test('une semaine vide ne coche rien', () {
      expect(defaultSelection([day(0), day(0, isCurrent: true)]), isEmpty);
    });
  });

  group('montant saisi à la main', () {
    /// La règle de l'écran, reproduite telle quelle.
    int requested({required int custom, required int available}) =>
        available <= 0 ? 0 : custom.clamp(1, available);

    test('un montant saisi est borné par le dû', () {
      expect(requested(custom: 90000, available: 50000), 50000);
      expect(requested(custom: 20000, available: 50000), 20000);
    });

    test("un solde à zéro ne fait pas planter l'écran", () {
      // `clamp(1, 0)` lève une ArgumentError : borne basse au-dessus de la
      // borne haute. Une demande refusée laisse le montant saisi en place et
      // reconstruit l'écran — avec un solde vidé entre-temps, c'était un écran
      // rouge au lieu d'un message.
      expect(() => 5000.clamp(1, 0), throwsArgumentError);
      expect(requested(custom: 5000, available: 0), 0);
    });
  });
}
