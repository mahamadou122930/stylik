import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/settings/domain/subscription.dart';

void main() {
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  group('Subscription - Période d\'essai Pro 15 jours', () {
    test('Un abonnement trialing actif est identifié comme trial et actif', () {
      final now = DateTime.now();
      final in15Days = now.add(const Duration(days: 15));

      final sub = Subscription(
        id: 'sub-1',
        salonId: 'salon-1',
        planCode: 'pro',
        planName: 'Pro Salon',
        pricePerMonthFcfa: 18000,
        status: 'trialing',
        nextChargeAt: in15Days,
      );

      expect(sub.isTrial, isTrue);
      expect(sub.isExpired, isFalse);
      expect(sub.isActive, isTrue);
      expect(sub.trialDaysRemaining, inInclusiveRange(14, 15));
      expect(sub.statusLabel, contains('Essai'));
    });

    test(
      'Un abonnement trialing expiré est inactif et affiche Essai expiré',
      () {
        final past = DateTime.now().subtract(const Duration(days: 1));

        final sub = Subscription(
          id: 'sub-2',
          salonId: 'salon-1',
          planCode: 'pro',
          planName: 'Pro Salon',
          pricePerMonthFcfa: 18000,
          status: 'trialing',
          nextChargeAt: past,
        );

        expect(sub.isTrial, isTrue);
        expect(sub.isExpired, isTrue);
        expect(sub.isActive, isFalse);
        expect(sub.trialDaysRemaining, equals(0));
        expect(sub.statusLabel, equals('Essai expiré'));
        expect(sub.nextChargeLabel, equals('Période d\'essai terminée'));
      },
    );

    test('Un abonnement active payant reste actif normalement', () {
      final in30Days = DateTime.now().add(const Duration(days: 30));

      final sub = Subscription(
        id: 'sub-3',
        salonId: 'salon-1',
        planCode: 'pro',
        planName: 'Pro Salon',
        pricePerMonthFcfa: 18000,
        status: 'active',
        nextChargeAt: in30Days,
      );

      expect(sub.isTrial, isFalse);
      expect(sub.isExpired, isFalse);
      expect(sub.isActive, isTrue);
      expect(sub.statusLabel, equals('Actif'));
      expect(sub.nextChargeLabel, startsWith('Prochain prélèvement'));
    });

    test('Désérialisation fromMap avec statut trialing', () {
      final map = {
        'id': 'sub-map-1',
        'salon_id': 'salon-123',
        'plan_code': 'pro',
        'plan_name': 'Pro Salon',
        'price_per_month_fcfa': 18000,
        'billing_cycle': 'monthly',
        'status': 'trialing',
        'features': ['Jusqu\'à 10 employés'],
        'payment_label': 'Essai gratuit (15 jours)',
        'next_charge_at': DateTime.now()
            .add(const Duration(days: 15))
            .toIso8601String(),
      };

      final sub = Subscription.fromMap(map);
      expect(sub.planCode, equals('pro'));
      expect(sub.isTrial, isTrue);
      expect(sub.isActive, isTrue);
      expect(sub.pricePerMonthFcfa, equals(18000));
    });
  });

  group("progression de l'essai", () {
    Subscription trialEndingIn(Duration remaining) => Subscription(
      id: 'sub',
      salonId: 'salon',
      planCode: 'pro',
      planName: 'Pro Salon',
      pricePerMonthFcfa: 18000,
      status: 'trialing',
      nextChargeAt: DateTime.now().add(remaining),
    );

    test('la barre part de zero et finit pleine', () {
      // Les ecrans calculaient chacun leur « 15 » en dur : une duree changee
      // un jour les aurait laisses mentir sans que rien ne le signale.
      expect(trialEndingIn(const Duration(days: 15)).trialProgress, 0);
      expect(trialEndingIn(const Duration(days: -1)).trialProgress, 1);
    });

    test('a mi-parcours, la barre est a la moitie', () {
      final progress = trialEndingIn(
        const Duration(days: 7, hours: 12),
      ).trialProgress;
      expect(progress, closeTo(0.5, 0.07));
    });

    test("le debut de l'essai se deduit de son echeance", () {
      final sub = trialEndingIn(const Duration(days: 15));
      final elapsed = DateTime.now().difference(sub.trialStartedAt!);
      expect(elapsed.inSeconds.abs(), lessThan(5));
    });

    test("sans echeance, rien n'est invente", () {
      const sub = Subscription(
        id: 'sub',
        salonId: 'salon',
        planCode: 'pro',
        planName: 'Pro Salon',
        pricePerMonthFcfa: 18000,
        status: 'trialing',
      );
      expect(sub.trialStartedAt, isNull);
      expect(sub.trialProgress, 0);
      expect(sub.trialDaysRemaining, 0);
    });
  });
}
