import '../../pos/domain/payment_method.dart';

/// Synthèse financière d'une période (jour, semaine, mois).
class FinanceSummary {
  const FinanceSummary({
    required this.from,
    required this.to,
    required this.revenueFcfa,
    required this.ticketCount,
    this.collectedFcfa = 0,
    this.pendingFcfa = 0,
    this.previousRevenueFcfa,
    this.revenueByMethod = const {},
    this.buckets = const [],
    this.commissionsFcfa = 0,
  });

  final DateTime from;
  final DateTime to;

  /// Chiffre d'affaires facturé sur la période.
  final int revenueFcfa;

  final int ticketCount;

  /// Part effectivement encaissée et part en attente de règlement.
  final int collectedFcfa;
  final int pendingFcfa;

  /// CA de la période précédente, pour l'écart affiché sur la carte.
  final int? previousRevenueFcfa;

  /// Répartition du CA par moyen de paiement.
  final Map<PaymentMethod, int> revenueByMethod;

  /// Découpage interne de la période (S1…S4, ou jours de la semaine).
  final List<FinanceBucket> buckets;

  /// Total des commissions dues aux coiffeurs.
  final int commissionsFcfa;

  /// Panier moyen.
  int get averageTicketFcfa =>
      ticketCount == 0 ? 0 : (revenueFcfa / ticketCount).round();

  /// Évolution en pourcentage par rapport à la période précédente.
  int? get growthPercent {
    final previous = previousRevenueFcfa;
    if (previous == null || previous == 0) return null;
    return ((revenueFcfa - previous) / previous * 100).round();
  }

  /// Synthèse vide pour une période donnée (aucun encaissement).
  factory FinanceSummary.empty({
    required DateTime from,
    required DateTime to,
  }) => FinanceSummary(from: from, to: to, revenueFcfa: 0, ticketCount: 0);
}

/// Point de la série temporelle affichée en histogramme.
class FinanceBucket {
  const FinanceBucket({required this.label, required this.revenueFcfa});

  final String label;
  final int revenueFcfa;
}

/// Commission due à un coiffeur sur une période.
class StylistCommission {
  const StylistCommission({
    required this.stylistId,
    required this.stylistName,
    required this.revenueFcfa,
    required this.commissionFcfa,
    required this.serviceCount,
    this.commissionRate = 0,
    this.speciality,
    this.clientCount = 0,
  });

  final String stylistId;
  final String stylistName;
  final int revenueFcfa;
  final int commissionFcfa;
  final int serviceCount;

  /// Taux appliqué, en pourcentage (35 pour 35 %).
  final double commissionRate;

  /// Spécialité affichée sous le nom (« Coloriste »).
  final String? speciality;

  final int clientCount;

  factory StylistCommission.fromMap(Map<String, dynamic> map) =>
      StylistCommission(
        stylistId: (map['stylist_id'] as String?) ?? '',
        stylistName: (map['stylist_name'] as String?) ?? '',
        revenueFcfa: (map['revenue_fcfa'] as num?)?.toInt() ?? 0,
        commissionFcfa: (map['commission_fcfa'] as num?)?.toInt() ?? 0,
        serviceCount: (map['service_count'] as num?)?.toInt() ?? 0,
        commissionRate: (map['commission_rate'] as num?)?.toDouble() ?? 0,
        speciality: map['speciality'] as String?,
        clientCount: (map['client_count'] as num?)?.toInt() ?? 0,
      );
}

/// Performance d'une prestation sur la période (rapport par service).
class ServicePerformance {
  const ServicePerformance({
    required this.serviceId,
    required this.name,
    required this.category,
    required this.count,
    required this.revenueFcfa,
    this.isProduct = false,
  });

  final String serviceId;
  final String name;
  final String category;
  final int count;
  final int revenueFcfa;

  /// Vente de produit plutôt que prestation.
  ///
  /// Les deux pèsent sur le chiffre d'affaires et doivent donc figurer dans
  /// la répartition, mais ne se comptent pas pareil : « 3 prestations » sur
  /// un shampooing vendu se lirait comme trois passages en fauteuil.
  final bool isProduct;

  /// Libellé du volume, adapté à la nature de la ligne.
  String get countLabel => isProduct
      ? '$count ${count > 1 ? 'unités vendues' : 'unité vendue'}'
      : '$count ${count > 1 ? 'prestations' : 'prestation'}';

  /// Dernier filet contre les libellés vides : une catégorie blanche donnait
  /// une part colorée sans légende, impossible à rattacher à quoi que ce soit.
  /// Le repli existe déjà à la lecture des lignes, mais la RPC est un second
  /// chemin d'entrée qu'il faut couvrir aussi.
  static String _orDefault(Object? value, String fallback) {
    final text = (value as String?)?.trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  factory ServicePerformance.fromMap(Map<String, dynamic> map) =>
      ServicePerformance(
        serviceId: (map['service_id'] as String?) ?? '',
        name: _orDefault(
          map['name'],
          ((map['is_product'] as bool?) ?? false) ? 'Produit' : 'Prestation',
        ),
        category: _orDefault(map['category'], 'Autre'),
        count: (map['count'] as num?)?.toInt() ?? 0,
        revenueFcfa: (map['revenue_fcfa'] as num?)?.toInt() ?? 0,
        isProduct: (map['is_product'] as bool?) ?? false,
      );
}

/// Catégorie de dépense (`expenses.category`).
enum ExpenseCategory {
  rent('rent', 'Loyer'),
  supplies('supplies', 'Réappro. produits'),
  utilities('utilities', 'Énergie & eau'),
  payroll('payroll', 'Salaires & commissions'),
  marketing('marketing', 'Marketing'),
  other('other', 'Autre');

  const ExpenseCategory(this.value, this.label);

  final String value;
  final String label;

  static ExpenseCategory fromValue(String? value) => ExpenseCategory.values
      .firstWhere((category) => category.value == value, orElse: () => other);
}

/// Dépense / charge du salon — table `expenses`.
class Expense {
  const Expense({
    required this.id,
    required this.salonId,
    required this.label,
    required this.amountFcfa,
    required this.category,
    required this.spentAt,
    this.supplier,
    this.isRecurring = false,
  });

  final String id;
  final String salonId;
  final String label;
  final int amountFcfa;
  final ExpenseCategory category;
  final DateTime spentAt;
  final String? supplier;
  final bool isRecurring;

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as String,
    salonId: map['salon_id'] as String,
    label: (map['label'] as String?) ?? '',
    amountFcfa: (map['amount_fcfa'] as num?)?.toInt() ?? 0,
    category: ExpenseCategory.fromValue(map['category'] as String?),
    spentAt: DateTime.parse(map['spent_at'] as String).toLocal(),
    supplier: map['supplier'] as String?,
    isRecurring: (map['is_recurring'] as bool?) ?? false,
  );

  Map<String, dynamic> toMap() => {
    'salon_id': salonId,
    'label': label,
    'amount_fcfa': amountFcfa,
    'category': category.value,
    'spent_at': spentAt.toUtc().toIso8601String(),
    'supplier': supplier,
    'is_recurring': isRecurring,
  };
}
