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

  group('répartition des versements sur les journées', () {
    /// La règle de `_computeDayInfos`, reproduite à l'identique.
    List<({int settled, int remaining})> allocate({
      required List<int> days,
      required int totalPaid,
      required int earnedBeforeWindow,
    }) {
      final windowTotal = days.fold<int>(0, (s, d) => s + d);
      var budget = (totalPaid - earnedBeforeWindow).clamp(0, windowTotal);
      final out = <({int settled, int remaining})>[];
      for (final d in days) {
        if (budget >= d) {
          out.add((settled: d, remaining: 0));
          budget -= d;
        } else if (budget > 0) {
          out.add((settled: budget, remaining: d - budget));
          budget = 0;
        } else {
          out.add((settled: 0, remaining: d));
        }
      }
      return out;
    }

    test('les versements anciens ne consomment pas les journées récentes', () {
      // Le cas remonté : 10 350 F gagnés depuis l'ouverture, 9 450 F versés,
      // donc 900 F dus. La fenêtre n'affiche que 2 100 F de commissions
      // récentes ; le reste a été gagné avant.
      const days = [450, 450, 300, 450, 450];
      const totalPaid = 9450;
      const earnedTotal = 10350;
      final earnedBefore = earnedTotal - days.fold<int>(0, (s, d) => s + d);

      final rows = allocate(
        days: days,
        totalPaid: totalPaid,
        earnedBeforeWindow: earnedBefore,
      );

      final reclaimable = rows.fold<int>(0, (s, r) => s + r.remaining);
      // Dépenser les 9 450 F sur la seule fenêtre marquait les cinq journées
      // comme réglées et ne laissait rien à réclamer.
      expect(reclaimable, 900);
      expect(rows.where((r) => r.remaining > 0).length, 2);
    });

    test('sans historique antérieur, la répartition reste inchangée', () {
      final rows = allocate(
        days: const [500, 500, 500],
        totalPaid: 700,
        earnedBeforeWindow: 0,
      );

      expect(rows[0].remaining, 0);
      expect(rows[1].remaining, 300);
      expect(rows[2].remaining, 500);
    });

    test('tout réglé ne laisse aucune journée à réclamer', () {
      final rows = allocate(
        days: const [400, 600],
        totalPaid: 1000,
        earnedBeforeWindow: 0,
      );

      expect(rows.every((r) => r.remaining == 0), isTrue);
    });

    test('un versement dépassant la fenêtre ne creuse pas les journées', () {
      // Le budget est borné au total de la fenêtre : sans cela, un reliquat
      // négatif aurait pu réapparaître ailleurs.
      final rows = allocate(
        days: const [200],
        totalPaid: 5000,
        earnedBeforeWindow: 0,
      );

      expect(rows.single.settled, 200);
      expect(rows.single.remaining, 0);
    });
  });

  group('journées réglées, vue gérant', () {
    /// La règle de `_settledDayKeys`, reproduite à l'identique.
    List<bool> settledFlags({
      required List<int> days,
      required int availableBalance,
    }) {
      final windowTotal = days.fold<int>(0, (s, d) => s + d);
      var budget = (windowTotal - availableBalance).clamp(0, windowTotal);
      final out = <bool>[];
      var stopped = false;
      for (final d in days) {
        if (!stopped && budget >= d) {
          out.add(true);
          budget -= d;
        } else {
          stopped = true;
          out.add(false);
        }
      }
      return out;
    }

    int stillDue(List<int> days, List<bool> settled) {
      var t = 0;
      for (var i = 0; i < days.length; i++) {
        if (!settled[i]) t += days[i];
      }
      return t;
    }

    test('le reste affiché colle à la pastille « Dû »', () {
      // Le cas remonté : quatre journées de 450 F, 900 F encore dus. Comparer
      // les 9 450 F versés depuis l'ouverture au cumul de la seule fenêtre
      // marquait les quatre journées réglées et annonçait « 0 F » sous une
      // pastille disant « Dû : 900 F ».
      const days = [450, 450, 450, 450];
      final flags = settledFlags(days: days, availableBalance: 900);

      expect(flags, [true, true, false, false]);
      expect(stillDue(days, flags), 900);
    });

    test('rien de versé laisse toutes les journées réclamables', () {
      const days = [450, 450];
      final flags = settledFlags(days: days, availableBalance: 900);

      expect(flags, [false, false]);
      expect(stillDue(days, flags), 900);
    });

    test('tout réglé éteint toutes les journées', () {
      const days = [450, 450];
      final flags = settledFlags(days: days, availableBalance: 0);

      expect(flags.every((f) => f), isTrue);
      expect(stillDue(days, flags), 0);
    });

    test('une journée partiellement couverte reste réclamable', () {
      // 700 F couverts sur 1 000 : la solder entièrement effacerait 300 F dus.
      const days = [1000, 500];
      final flags = settledFlags(days: days, availableBalance: 800);

      expect(flags, [false, false]);
      expect(stillDue(days, flags), 1500);
    });
  });
}
