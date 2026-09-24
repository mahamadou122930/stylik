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

  /// Durée de l'essai offert à la création d'un salon.
  ///
  /// Une seule source : les écrans en déduisaient chacun leur « 15 » en dur,
  /// et une durée changée un jour aurait laissé les barres de progression
  /// mentir sans que rien ne le signale.
  static const int trialDurationDays = 15;

  /// Début de l'essai, déduit de son échéance.
  DateTime? get trialStartedAt =>
      nextChargeAt?.subtract(const Duration(days: trialDurationDays));

  /// Part de l'essai déjà consommée, entre 0 et 1.
  double get trialProgress {
    if (nextChargeAt == null) return 0;
    final elapsed = trialDurationDays - trialDaysRemaining;
    return (elapsed / trialDurationDays).clamp(0.0, 1.0);
  }

  /// Indique si l'abonnement est en période d'essai (15 jours).
  bool get isTrial => status == 'trialing';

  /// Indique si la date d'échéance / fin d'essai est dépassée.
  bool get isExpired =>
      nextChargeAt != null && DateTime.now().isAfter(nextChargeAt!);

  /// Nombre de jours restants avant la fin de la période d'essai.
  int get trialDaysRemaining {
    if (nextChargeAt == null) return 0;
    final diffHours = nextChargeAt!.difference(DateTime.now()).inHours;
    if (diffHours <= 0) return 0;
    return (diffHours / 24).ceil();
  }

  /// Actif si formule payante active ou période d'essai non expirée.
  bool get isActive =>
      status == 'active' || (status == 'trialing' && !isExpired);

  String get statusLabel => switch (status) {
    'active' => 'Actif',
    'trialing' =>
      isExpired
          ? 'Essai expiré'
          : (trialDaysRemaining <= 1
                ? 'Dernier jour d\'essai'
                : 'Essai ($trialDaysRemaining j)'),
    'past_due' => 'Impayé',
    'canceled' => 'Résilié',
    _ => status,
  };

  String get nextChargeLabel {
    if (nextChargeAt == null) return 'Aucun prélèvement planifié';
    if (isTrial) {
      if (isExpired) return 'Période d\'essai terminée';
      return 'Fin de l\'essai le ${Formatters.dayMonth(nextChargeAt!)}';
    }
    return 'Prochain prélèvement ${Formatters.dayMonth(nextChargeAt!)}';
  }

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
    pricePerMonthFcfa: (map['price_per_month_fcfa'] as num?)?.toInt() ?? 0,
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
