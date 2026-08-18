/// Usage d'un produit : revendu au client ou consommé en cabine.
enum ProductUsage {
  resale('resale', 'Revendu au client'),
  consumable('consumable', 'Consommé en soin');

  const ProductUsage(this.value, this.label);

  final String value;
  final String label;

  static ProductUsage fromValue(String? value) => ProductUsage.values
      .firstWhere((usage) => usage.value == value, orElse: () => resale);
}

/// Niveau de stock d'un produit, pour l'affichage des puces.
enum StockLevel { ok, low, out }

/// Produit en stock — table `products`.
class Product {
  const Product({
    required this.id,
    required this.salonId,
    required this.name,
    required this.brand,
    required this.category,
    required this.stockQuantity,
    required this.alertThreshold,
    required this.unitSalePriceFcfa,
    this.unitCostFcfa = 0,
    this.supplier,
    this.packaging,
    this.usage = ProductUsage.resale,
    this.isActive = true,
  });

  final String id;
  final String salonId;
  final String name;
  final String brand;

  /// Coloration, soin, revente, consommable…
  final String category;

  final int stockQuantity;

  /// Seuil déclenchant une alerte de réapprovisionnement.
  final int alertThreshold;

  final int unitSalePriceFcfa;
  final int unitCostFcfa;

  /// Fournisseur habituel.
  final String? supplier;

  /// Conditionnement (« Bidon 1 L », « Tube 60 ml »).
  final String? packaging;

  final ProductUsage usage;
  final bool isActive;

  StockLevel get level {
    if (stockQuantity <= 0) return StockLevel.out;
    if (stockQuantity <= alertThreshold) return StockLevel.low;
    return StockLevel.ok;
  }

  bool get isLowStock => level != StockLevel.ok;
  bool get isOutOfStock => level == StockLevel.out;

  /// Valeur du stock détenu, au prix d'achat.
  int get stockValueFcfa => stockQuantity * unitCostFcfa;

  /// Libellé de la puce de stock (« 12 en stock », « 2 restants », « Rupture »).
  String get stockLabel => switch (level) {
    StockLevel.out => 'Rupture',
    StockLevel.low => '$stockQuantity restants',
    StockLevel.ok => '$stockQuantity en stock',
  };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'] as String,
    salonId: map['salon_id'] as String,
    name: (map['name'] as String?) ?? '',
    brand: (map['brand'] as String?) ?? '',
    category: (map['category'] as String?) ?? 'Autre',
    stockQuantity: (map['stock_quantity'] as num?)?.toInt() ?? 0,
    alertThreshold: (map['alert_threshold'] as num?)?.toInt() ?? 0,
    unitSalePriceFcfa: (map['unit_sale_price_fcfa'] as num?)?.toInt() ?? 0,
    unitCostFcfa: (map['unit_cost_fcfa'] as num?)?.toInt() ?? 0,
    supplier: map['supplier'] as String?,
    packaging: map['packaging'] as String?,
    usage: ProductUsage.fromValue(map['usage'] as String?),
    isActive: (map['is_active'] as bool?) ?? true,
  );

  Map<String, dynamic> toMap() => {
    'salon_id': salonId,
    'name': name,
    'brand': brand,
    'category': category,
    'stock_quantity': stockQuantity,
    'alert_threshold': alertThreshold,
    'unit_sale_price_fcfa': unitSalePriceFcfa,
    'unit_cost_fcfa': unitCostFcfa,
    'supplier': supplier,
    'packaging': packaging,
    'usage': usage.value,
    'is_active': isActive,
  };

  Product copyWith({
    String? name,
    String? brand,
    String? category,
    int? stockQuantity,
    int? alertThreshold,
    int? unitSalePriceFcfa,
    int? unitCostFcfa,
    String? supplier,
    String? packaging,
    ProductUsage? usage,
    bool? isActive,
  }) => Product(
    id: id,
    salonId: salonId,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    category: category ?? this.category,
    stockQuantity: stockQuantity ?? this.stockQuantity,
    alertThreshold: alertThreshold ?? this.alertThreshold,
    unitSalePriceFcfa: unitSalePriceFcfa ?? this.unitSalePriceFcfa,
    unitCostFcfa: unitCostFcfa ?? this.unitCostFcfa,
    supplier: supplier ?? this.supplier,
    packaging: packaging ?? this.packaging,
    usage: usage ?? this.usage,
    isActive: isActive ?? this.isActive,
  );
}

/// Mouvement de stock — table `stock_movements`.
///
/// `quantity` est positif en réception, négatif en consommation ou en vente.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.salonId,
    required this.productId,
    required this.quantity,
    required this.reason,
    required this.occurredAt,
    this.productName,
    this.unitLabel,
    this.contextLabel,
    this.costFcfa = 0,
  });

  final String id;
  final String salonId;
  final String productId;
  final int quantity;

  /// `reception`, `consumption`, `sale`, `adjustment`, `loss`.
  final String reason;

  final DateTime occurredAt;

  /// Champs dénormalisés pour l'affichage.
  final String? productName;

  /// Unité consommée (« 120 ml », « 1 tube »).
  final String? unitLabel;

  /// Contexte (« Balayage · Sophie B. »).
  final String? contextLabel;

  final int costFcfa;

  bool get isConsumption => reason == 'consumption';

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
    id: map['id'] as String,
    salonId: map['salon_id'] as String,
    productId: map['product_id'] as String,
    quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    reason: (map['reason'] as String?) ?? 'adjustment',
    occurredAt: DateTime.parse(map['occurred_at'] as String).toLocal(),
    productName: map['products'] is Map<String, dynamic>
        ? (map['products'] as Map<String, dynamic>)['name'] as String?
        : map['product_name'] as String?,
    unitLabel: map['unit_label'] as String?,
    contextLabel: map['context_label'] as String?,
    costFcfa: (map['cost_fcfa'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'salon_id': salonId,
    'product_id': productId,
    'quantity': quantity,
    'reason': reason,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'unit_label': unitLabel,
    'context_label': contextLabel,
    'cost_fcfa': costFcfa,
  };
}
