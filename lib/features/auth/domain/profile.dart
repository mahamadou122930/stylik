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
    this.avatarUrl,
    this.phone,
    this.email,
    this.userId,
    this.isActive = true,
    this.leaveBalanceDays = 0,
  });

  final String id;
  final String salonId;

  /// Compte Supabase Auth rattaché, `null` tant que l'employé ne s'est pas
  /// inscrit. Un membre sans compte figure au planning mais ne se connecte pas.
  final String? userId;

  /// Email de rattachement : à l'inscription, le déclencheur `handle_new_user`
  /// réclame la fiche portant cet email au lieu d'en créer une seconde.
  final String? email;

  /// `true` si l'employé peut se connecter à l'application.
  bool get hasAccount => userId != null;
  final String fullName;
  final UserRole role;

  /// Spécialités du coiffeur (tresses, coloration, barbe…).
  final List<String> specialties;

  /// Taux de commission en pourcentage (ex. 30 pour 30 %).
  final double commissionRate;

  final String? avatarUrl;
  final String? phone;
  final bool isActive;

  /// Jours de congés restants, affichés sur la fiche employé (4.2).
  final int leaveBalanceDays;

  /// Colonnes à demander à PostgREST. Liste explicite plutôt que `select()` :
  /// `pin_code` ne doit jamais quitter la base — n'importe quel membre du salon
  /// pourrait sinon lire le code caisse de ses collègues. Sa vérification passe
  /// exclusivement par la RPC `verify_pin`.
  static const String columns =
      'id, user_id, salon_id, full_name, role, specialties, commission_rate, '
      'avatar_url, phone, email, is_active, leave_balance_days';

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        fullName: (map['full_name'] as String?) ?? '',
        role: UserRole.fromValue(map['role'] as String?),
        specialties:
            (map['specialties'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        commissionRate: (map['commission_rate'] as num?)?.toDouble() ?? 0,
        avatarUrl: map['avatar_url'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        userId: map['user_id'] as String?,
        isActive: (map['is_active'] as bool?) ?? true,
        leaveBalanceDays: (map['leave_balance_days'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'salon_id': salonId,
        'full_name': fullName,
        'role': role.value,
        'specialties': specialties,
        'commission_rate': commissionRate,
        'avatar_url': avatarUrl,
        'phone': phone,
        'email': email,
        'is_active': isActive,
        'leave_balance_days': leaveBalanceDays,
        // `user_id` est volontairement absent : il n'est écrit que par le
        // déclencheur `handle_new_user`, au rattachement du compte.
      };

  Profile copyWith({
    String? fullName,
    UserRole? role,
    List<String>? specialties,
    double? commissionRate,
    String? avatarUrl,
    String? phone,
    String? email,
    bool? isActive,
    int? leaveBalanceDays,
  }) =>
      Profile(
        id: id,
        salonId: salonId,
        fullName: fullName ?? this.fullName,
        role: role ?? this.role,
        specialties: specialties ?? this.specialties,
        commissionRate: commissionRate ?? this.commissionRate,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        userId: userId,
        isActive: isActive ?? this.isActive,
        leaveBalanceDays: leaveBalanceDays ?? this.leaveBalanceDays,
      );
}
