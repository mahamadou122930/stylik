import '../../../core/utils/formatters.dart';

/// Genre du client (`clients.gender`).
enum ClientGender {
  female('female', 'Femme'),
  male('male', 'Homme'),
  other('other', 'Autre');

  const ClientGender(this.value, this.label);

  final String value;
  final String label;

  static ClientGender fromValue(String? value) => ClientGender.values.firstWhere(
        (gender) => gender.value == value,
        orElse: () => ClientGender.other,
      );
}

/// Fiche client — table `clients`.
class Client {
  const Client({
    required this.id,
    required this.salonId,
    required this.fullName,
    required this.phone,
    this.gender = ClientGender.other,
    this.allergiesNotes,
    this.loyaltyPoints = 0,
    this.tags = const [],
    this.photoBeforeUrl,
    this.photoAfterUrl,
    this.createdAt,
    this.visitCount = 0,
    this.totalSpentFcfa = 0,
    this.lastVisitAt,
    this.preferences = const {},
  });

  final String id;
  final String salonId;
  final String fullName;
  final String phone;
  final ClientGender gender;

  /// Allergies / sensibilités et notes techniques (cheveux, produits).
  final String? allergiesNotes;

  final int loyaltyPoints;

  /// Étiquettes CRM : VIP, mariage, coloration, à relancer…
  final List<String> tags;

  final String? photoBeforeUrl;
  final String? photoAfterUrl;
  final DateTime? createdAt;

  /// Agrégats de fréquentation (colonnes calculées côté base).
  final int visitCount;
  final int totalSpentFcfa;
  final DateTime? lastVisitAt;

  /// Préférences libres (« Couleur » → « Balayage caramel »).
  final Map<String, dynamic> preferences;

  bool get isVip => tags.contains('VIP');

  /// Client fidèle à partir de 10 visites.
  bool get isLoyal => visitCount >= 10;

  bool get hasAllergies => allergiesNotes?.trim().isNotEmpty ?? false;

  /// Nombre de jours depuis la dernière visite.
  int? get daysSinceLastVisit => lastVisitAt == null
      ? null
      : DateTime.now().difference(lastVisitAt!).inDays;

  /// « Dern. visite 12 j · 8 visites ».
  String get activityLabel {
    final days = daysSinceLastVisit;
    return [
      if (days != null) 'Dern. visite $days j' else 'Jamais venu',
      '$visitCount visite${visitCount > 1 ? 's' : ''}',
    ].join(' · ');
  }

  /// Initiales affichées dans les avatars.
  String get initials => Formatters.initials(fullName);

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        fullName: (map['full_name'] as String?) ?? '',
        phone: (map['phone'] as String?) ?? '',
        gender: ClientGender.fromValue(map['gender'] as String?),
        allergiesNotes: map['allergies_notes'] as String?,
        loyaltyPoints: (map['loyalty_points'] as num?)?.toInt() ?? 0,
        tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        photoBeforeUrl: map['photo_before_url'] as String?,
        photoAfterUrl: map['photo_after_url'] as String?,
        createdAt: map['created_at'] == null
            ? null
            : DateTime.parse(map['created_at'] as String).toLocal(),
        visitCount: (map['visit_count'] as num?)?.toInt() ?? 0,
        totalSpentFcfa: (map['total_spent_fcfa'] as num?)?.toInt() ?? 0,
        lastVisitAt: map['last_visit_at'] == null
            ? null
            : DateTime.parse(map['last_visit_at'] as String).toLocal(),
        preferences:
            (map['preferences'] as Map<String, dynamic>?) ?? const {},
      );

  Map<String, dynamic> toMap() => {
        'salon_id': salonId,
        'full_name': fullName,
        'phone': phone,
        'gender': gender.value,
        'allergies_notes': allergiesNotes,
        'loyalty_points': loyaltyPoints,
        'tags': tags,
        'photo_before_url': photoBeforeUrl,
        'photo_after_url': photoAfterUrl,
        'preferences': preferences,
      };

  Client copyWith({
    String? fullName,
    String? phone,
    ClientGender? gender,
    String? allergiesNotes,
    int? loyaltyPoints,
    List<String>? tags,
    String? photoBeforeUrl,
    String? photoAfterUrl,
  }) =>
      Client(
        id: id,
        salonId: salonId,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        gender: gender ?? this.gender,
        allergiesNotes: allergiesNotes ?? this.allergiesNotes,
        loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
        tags: tags ?? this.tags,
        photoBeforeUrl: photoBeforeUrl ?? this.photoBeforeUrl,
        photoAfterUrl: photoAfterUrl ?? this.photoAfterUrl,
        createdAt: createdAt,
        visitCount: visitCount,
        totalSpentFcfa: totalSpentFcfa,
        lastVisitAt: lastVisitAt,
        preferences: preferences,
      );
}
