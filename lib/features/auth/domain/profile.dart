import 'user_role.dart';

/// Membre du personnel — table `profiles` (id = auth.users.id).
class Profile {
  const Profile({
    required this.id,
    required this.salonId,
    required this.fullName,
    required this.role,
    this.specialties = const [],
    this.commissionRate = 0,
    this.pinCode,
    this.avatarUrl,
    this.phone,
    this.isActive = true,
  });

  final String id;
  final String salonId;
  final String fullName;
  final UserRole role;

  /// Spécialités du coiffeur (tresses, coloration, barbe…).
  final List<String> specialties;

  /// Taux de commission en pourcentage (ex. 30 pour 30 %).
  final double commissionRate;

  /// Code PIN de déverrouillage rapide en caisse.
  final String? pinCode;

  final String? avatarUrl;
  final String? phone;
  final bool isActive;

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        fullName: (map['full_name'] as String?) ?? '',
        role: UserRole.fromValue(map['role'] as String?),
        specialties:
            (map['specialties'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        commissionRate: (map['commission_rate'] as num?)?.toDouble() ?? 0,
        pinCode: map['pin_code'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        phone: map['phone'] as String?,
        isActive: (map['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'salon_id': salonId,
        'full_name': fullName,
        'role': role.value,
        'specialties': specialties,
        'commission_rate': commissionRate,
        'pin_code': pinCode,
        'avatar_url': avatarUrl,
        'phone': phone,
        'is_active': isActive,
      };

  Profile copyWith({
    String? fullName,
    UserRole? role,
    List<String>? specialties,
    double? commissionRate,
    String? pinCode,
    String? avatarUrl,
    String? phone,
    bool? isActive,
  }) =>
      Profile(
        id: id,
        salonId: salonId,
        fullName: fullName ?? this.fullName,
        role: role ?? this.role,
        specialties: specialties ?? this.specialties,
        commissionRate: commissionRate ?? this.commissionRate,
        pinCode: pinCode ?? this.pinCode,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        phone: phone ?? this.phone,
        isActive: isActive ?? this.isActive,
      );
}
