/// Prestation ou forfait — table `services`.
class SalonService {
  const SalonService({
    required this.id,
    required this.salonId,
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.priceFcfa,
    this.commissionRate = 0,
    this.isPackage = false,
    this.includedServiceIds = const [],
    this.isActive = true,
    this.description,
    this.isBookableOnline = true,
    this.originalPriceFcfa,
  });

  final String id;
  final String salonId;
  final String name;

  /// Coupe, coloration, tresses, barbe, soin…
  final String category;

  final int durationMinutes;
  final int priceFcfa;

  /// Commission spécifique à la prestation (prioritaire sur celle du coiffeur).
  final double commissionRate;

  /// `true` pour un forfait regroupant plusieurs prestations.
  final bool isPackage;
  final List<String> includedServiceIds;

  final bool isActive;

  /// Descriptif affiché dans la fiche et sur la réservation en ligne.
  final String? description;

  final bool isBookableOnline;

  /// Prix cumulé des prestations incluses, pour un forfait (prix barré).
  final int? originalPriceFcfa;

  /// Remise du forfait en pourcentage, ou `null` si non applicable.
  int? get discountPercent {
    final original = originalPriceFcfa;
    if (!isPackage || original == null || original <= 0) return null;
    return ((original - priceFcfa) / original * 100).round();
  }

  factory SalonService.fromMap(Map<String, dynamic> map) => SalonService(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        name: (map['name'] as String?) ?? '',
        category: (map['category'] as String?) ?? 'Autre',
        durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 30,
        priceFcfa: (map['price_fcfa'] as num?)?.toInt() ?? 0,
        commissionRate: (map['commission_rate'] as num?)?.toDouble() ?? 0,
        isPackage: (map['is_package'] as bool?) ?? false,
        includedServiceIds: (map['included_service_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        isActive: (map['is_active'] as bool?) ?? true,
        description: map['description'] as String?,
        isBookableOnline: (map['is_bookable_online'] as bool?) ?? true,
        originalPriceFcfa: (map['original_price_fcfa'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'salon_id': salonId,
        'name': name,
        'category': category,
        'duration_minutes': durationMinutes,
        'price_fcfa': priceFcfa,
        'commission_rate': commissionRate,
        'is_package': isPackage,
        'included_service_ids': includedServiceIds,
        'is_active': isActive,
        'description': description,
        'is_bookable_online': isBookableOnline,
        'original_price_fcfa': originalPriceFcfa,
      };

  SalonService copyWith({
    String? name,
    String? category,
    int? durationMinutes,
    int? priceFcfa,
    double? commissionRate,
    bool? isPackage,
    List<String>? includedServiceIds,
    bool? isActive,
    String? description,
    bool? isBookableOnline,
    int? originalPriceFcfa,
  }) =>
      SalonService(
        id: id,
        salonId: salonId,
        name: name ?? this.name,
        category: category ?? this.category,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        priceFcfa: priceFcfa ?? this.priceFcfa,
        commissionRate: commissionRate ?? this.commissionRate,
        isPackage: isPackage ?? this.isPackage,
        includedServiceIds: includedServiceIds ?? this.includedServiceIds,
        isActive: isActive ?? this.isActive,
        description: description ?? this.description,
        isBookableOnline: isBookableOnline ?? this.isBookableOnline,
        originalPriceFcfa: originalPriceFcfa ?? this.originalPriceFcfa,
      );
}
