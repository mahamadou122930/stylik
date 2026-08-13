/// Longueur d'un code d'invitation, alignée sur `generate_invite_code()`.
const int inviteCodeLength = 6;

/// Salon reconnu derrière un code d'invitation, sur l'écran « Rejoindre un
/// salon ». Volontairement réduit au nom : tant que l'inscription n'a pas
/// abouti, la personne n'est rattachée à rien et ne doit rien voir de plus.
class SalonInvite {
  const SalonInvite({
    required this.code,
    required this.salonId,
    required this.salonName,
  });

  /// Le code saisi, normalisé en majuscules.
  final String code;
  final String salonId;
  final String salonName;
}
