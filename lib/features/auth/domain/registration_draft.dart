import 'dart:io';

import 'user_role.dart';

/// Saisie du parcours d'inscription, transportée de l'étape 1/2 (le salon et
/// le compte) à l'étape 2/2 (le rôle), où tout est envoyé d'un bloc.
class RegistrationDraft {
  const RegistrationDraft({
    required this.salonName,
    required this.salonPhone,
    required this.salonAddress,
    required this.fullName,
    required this.email,
    required this.password,
    this.logo,
    this.role = UserRole.gerant,
  });

  final String salonName;
  final String salonPhone;
  final String salonAddress;
  final String fullName;
  final String email;
  final String password;

  /// Logo choisi à l'étape 1/2, téléversé une fois le salon créé.
  final File? logo;

  final UserRole role;

  RegistrationDraft copyWith({UserRole? role}) => RegistrationDraft(
        salonName: salonName,
        salonPhone: salonPhone,
        salonAddress: salonAddress,
        fullName: fullName,
        email: email,
        password: password,
        logo: logo,
        role: role ?? this.role,
      );
}
