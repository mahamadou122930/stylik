import '../../../core/utils/formatters.dart';
import 'subscription_plan.dart';

/// Abonnement SaaS du salon — table `subscriptions`.
class Subscription {
  const Subscription({
    required this.id,
    required this.salonId,
    required this.planName,
    required this.pricePerMonthFcfa,
    required this.status,
    this.planCode,
    this.billingCycle = BillingCycle.monthly,
    this.features = const [],
    this.paymentLabel,
    this.nextChargeAt,
  });

  final String id;
  final String salonId;

  /// Code de la formule au catalogue (`solo`, `pro`, `multi`), si connu.
  final String? planCode;

  /// Nom commercial de la formule (« Pro Salon »).
  final String planName;

  final int pricePerMonthFcfa;

  /// Périodicité de facturation en cours.
  final BillingCycle billingCycle;

  /// `active`, `trialing`, `past_due`, `canceled`.
  final String status;

  /// Fonctionnalités incluses, affichées avec une coche.
  final List<String> features;

  /// Moyen de paiement masqué (« Orange Money · **** 4218 »).
  final String? paymentLabel;

  final DateTime? nextChargeAt;

  bool get isActive => status == 'active' || status == 'trialing';

  String get statusLabel => switch (status) {
        'active' => 'Actif',
        'trialing' => 'Essai',
        'past_due' => 'Impayé',
        'canceled' => 'Résilié',
        _ => status,
      };

  String get nextChargeLabel => nextChargeAt == null
      ? 'Aucun prélèvement planifié'
      : 'Prochain prélèvement ${Formatters.dayMonth(nextChargeAt!)}';

  /// Libellé de la périodicité affiché à côté du prix (« / mois », « / an »).
  String get periodLabel =>
      billingCycle == BillingCycle.annual ? '/ an' : '/ mois';

  /// Montant réellement prélevé à chaque échéance.
  int get chargeAmountFcfa => billingCycle.chargeAmount(pricePerMonthFcfa);

  factory Subscription.fromMap(Map<String, dynamic> map) => Subscription(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        planCode: map['plan_code'] as String?,
        billingCycle: BillingCycle.fromValue(map['billing_cycle'] as String?),
        planName: (map['plan_name'] as String?) ?? 'Formule',
        pricePerMonthFcfa:
            (map['price_per_month_fcfa'] as num?)?.toInt() ?? 0,
        status: (map['status'] as String?) ?? 'active',
        features:
            (map['features'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        paymentLabel: map['payment_label'] as String?,
        nextChargeAt: map['next_charge_at'] == null
            ? null
            : DateTime.parse(map['next_charge_at'] as String).toLocal(),
      );
}
