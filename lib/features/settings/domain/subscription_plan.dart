/// Périodicité de facturation — bascule « Mensuel / Annuel ».
///
/// La remise annuelle n'est plus portée ici. Elle était fixée à 20 % pour
/// toutes les formules, alors que la console la règle formule par formule et
/// que la base s'en sert pour calculer le montant d'une demande : changer la
/// remise dans la console aurait fait afficher un montant sur l'écran de
/// souscription et en réclamer un autre sur l'écran de paiement. Elle vit
/// désormais sur [SubscriptionPlan].
enum BillingCycle {
  monthly('monthly', 'Mensuel'),
  annual('annual', 'Annuel');

  const BillingCycle(this.value, this.label);

  final String value;
  final String label;

  static BillingCycle fromValue(String? value) => BillingCycle.values
      .firstWhere((cycle) => cycle.value == value, orElse: () => monthly);
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
    this.yearlyDiscount = defaultYearlyDiscount,
  });

  /// Remise annuelle d'une formule dont la base ne précise rien — la même
  /// valeur par défaut que la colonne `yearly_discount`.
  static const double defaultYearlyDiscount = 0.20;

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

  /// Remise sur l'engagement annuel, entre 0 et 1 (0.20 = −20 %). Réglée par
  /// formule depuis la console, et poussée ici avec le reste du catalogue.
  final double yearlyDiscount;

  bool has(PlanCapability capability) => capabilities.contains(capability);

  /// Montant à régler pour [cycle] : un mois, ou douze mois remisés.
  ///
  /// Le calcul reproduit celui de `request_subscription_activation`, au
  /// franc près : `round(prix × 12 × (1 − remise))` en arithmétique exacte,
  /// arrondi à l'entier le plus proche. L'ancien calcul arrondissait chaque
  /// mois avant de multiplier par douze — pour 10 001 F, l'écran annonçait
  /// 96 000 F quand la base en réclamait 96 010.
  ///
  /// En entiers plutôt qu'en `double` : 0.8 n'a pas d'écriture binaire exacte,
  /// et un montant qui tombe sur un demi-franc basculerait du mauvais côté.
  int chargeFor(BillingCycle cycle) {
    if (cycle == BillingCycle.monthly) return pricePerMonthFcfa;
    final keptBasisPoints = 10000 - (yearlyDiscount * 10000).round();
    return (pricePerMonthFcfa * 12 * keptBasisPoints + 5000) ~/ 10000;
  }

  /// Équivalent mensuel, pour comparer les formules d'un coup d'œil.
  int monthlyEquivalent(BillingCycle cycle) => cycle == BillingCycle.monthly
      ? pricePerMonthFcfa
      : (chargeFor(BillingCycle.annual) / 12).round();

  /// Tarif plein sur douze mois, barré face au prix remisé.
  int get fullYearPrice => pricePerMonthFcfa * 12;

  /// Remise affichée pour [cycle], en pourcentage entier.
  int discountPercentFor(BillingCycle cycle) =>
      cycle == BillingCycle.monthly ? 0 : (yearlyDiscount * 100).round();

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) =>
      SubscriptionPlan(
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
        features: ((map['features'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(),
        isPopular: (map['is_popular'] as bool?) ?? false,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        // `numeric` arrive tantôt en nombre, tantôt en chaîne selon le client.
        yearlyDiscount: switch (map['yearly_discount']) {
          final num value => value.toDouble(),
          final String value => double.tryParse(value) ?? defaultYearlyDiscount,
          _ => defaultYearlyDiscount,
        },
      );
}
