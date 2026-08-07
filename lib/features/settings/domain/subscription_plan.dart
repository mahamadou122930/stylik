/// Périodicité de facturation — bascule « Mensuel / Annuel −20 % ».
enum BillingCycle {
  monthly('monthly', 'Mensuel', 0),
  annual('annual', 'Annuel', 20);

  const BillingCycle(this.value, this.label, this.discountPercent);

  final String value;
  final String label;

  /// Remise appliquée à l'engagement annuel (0 pour le mensuel).
  final int discountPercent;

  static BillingCycle fromValue(String? value) => BillingCycle.values.firstWhere(
        (cycle) => cycle.value == value,
        orElse: () => monthly,
      );

  /// Prix mensuel réellement payé (le tarif annuel est remisé).
  int monthlyPrice(int basePricePerMonth) =>
      basePricePerMonth * (100 - discountPercent) ~/ 100;

  /// Montant prélevé à chaque échéance : un mois ou douze.
  int chargeAmount(int basePricePerMonth) => this == annual
      ? monthlyPrice(basePricePerMonth) * 12
      : monthlyPrice(basePricePerMonth);

  /// Tarif plein sur douze mois, barré face au prix remisé.
  int fullYearPrice(int basePricePerMonth) => basePricePerMonth * 12;

  /// Économie réalisée sur l'année en passant à l'annuel.
  int yearlySaving(int basePricePerMonth) =>
      fullYearPrice(basePricePerMonth) - chargeAmount(basePricePerMonth);

  /// Date du prochain prélèvement à partir d'aujourd'hui.
  DateTime nextChargeFrom(DateTime from) => this == annual
      ? DateTime(from.year + 1, from.month, from.day)
      : DateTime(from.year, from.month + 1, from.day);
}

/// Fonction comparée d'une formule à l'autre (tableau « Comparatif détaillé »).
enum PlanCapability {
  agenda('agenda', 'Agenda & RDV'),
  pos('pos', 'Caisse & clients'),
  team('team', 'Gestion d\'équipe'),
  reports('reports', 'Rapports & export'),
  messaging('messaging', 'SMS / WhatsApp');

  const PlanCapability(this.code, this.label);

  final String code;
  final String label;
}

/// Formule commerciale du catalogue SaaS — table `subscription_plans`.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.pricePerMonthFcfa,
    this.tagline,
    this.summary,
    this.capabilities = const [],
    this.features = const [],
    this.isPopular = false,
    this.sortOrder = 0,
  });

  final String id;

  /// Identifiant stable (`solo`, `pro`, `multi`) repris par `subscriptions`.
  final String code;

  final String name;

  /// Cible de la formule (« Salon avec équipe »).
  final String? tagline;

  /// Ligne descriptive sous le prix.
  final String? summary;

  final int pricePerMonthFcfa;

  /// Fonctions incluses, pour le tableau comparatif.
  final List<PlanCapability> capabilities;

  /// Puces « Inclus dans … » de l'écran d'abonnement.
  final List<String> features;

  /// Formule mise en avant (carte sombre, badge « Populaire »).
  final bool isPopular;

  final int sortOrder;

  bool has(PlanCapability capability) => capabilities.contains(capability);

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) => SubscriptionPlan(
        id: map['id'] as String,
        code: map['code'] as String,
        name: (map['name'] as String?) ?? 'Formule',
        tagline: map['tagline'] as String?,
        summary: map['summary'] as String?,
        pricePerMonthFcfa: (map['price_per_month_fcfa'] as num?)?.toInt() ?? 0,
        capabilities: ((map['capabilities'] as List?) ?? const [])
            .map((code) => PlanCapability.values.where((c) => c.code == code))
            .expand((matches) => matches)
            .toList(),
        features:
            ((map['features'] as List?) ?? const []).map((e) => '$e').toList(),
        isPopular: (map['is_popular'] as bool?) ?? false,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}
