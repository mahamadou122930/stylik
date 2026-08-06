import '../../../core/utils/formatters.dart';

/// Abonnement SaaS du salon — table `subscriptions`.
class Subscription {
  const Subscription({
    required this.id,
    required this.salonId,
    required this.planName,
    required this.pricePerMonthFcfa,
    required this.status,
    this.features = const [],
    this.paymentLabel,
    this.nextChargeAt,
  });

  final String id;
  final String salonId;

  /// Nom commercial de la formule (« Pro Salon »).
  final String planName;

  final int pricePerMonthFcfa;

  /// `active`, `trialing`, `past_due`, `canceled`.
  final String status;

  /// Fonctionnalités incluses, affichées avec une coche.
  final List<String> features;

  /// Moyen de paiement masqué (« Wave · **** 4218 »).
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

  factory Subscription.fromMap(Map<String, dynamic> map) => Subscription(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
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
