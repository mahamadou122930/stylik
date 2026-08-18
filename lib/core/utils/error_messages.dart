/// Traduction des erreurs techniques en messages affichables.
///
/// Un gérant de salon n'a rien à faire de
/// `AuthRetryableFetchException(message: ClientException with SocketException:
/// Failed host lookup… errno = 7)`. Il a besoin de savoir que sa connexion est
/// coupée, et qu'il peut réessayer.
abstract final class ErrorMessages {
  /// Signatures d'une coupure réseau, côté client comme côté plugin.
  ///
  /// Reconnaissance par le texte plutôt que par le type : la même panne
  /// remonte tantôt en `SocketException`, tantôt enveloppée dans une
  /// `AuthRetryableFetchException` ou une `ClientException`, selon la couche
  /// qui l'a interceptée.
  static const List<String> _offlineSignatures = [
    'socketexception',
    'failed host lookup',
    'clientexception',
    'connection closed',
    'connection refused',
    'connection reset',
    'network is unreachable',
    'no address associated with hostname',
    'timeoutexception',
    'operation timed out',
  ];

  /// `true` si l'erreur traduit une absence de réseau plutôt qu'un refus.
  static bool isOffline(Object? error) {
    if (error == null) return false;
    final text = error.toString().toLowerCase();
    return _offlineSignatures.any(text.contains);
  }

  static const String offlineMessage =
      'Pas de connexion. Vérifiez votre réseau, puis réessayez.';

  /// Message affichable pour [error].
  ///
  /// Seules les pannes réseau sont réécrites : les autres gardent leur texte
  /// d'origine, qui reste la seule piste exploitable pour diagnostiquer.
  static String humanize(Object? error) =>
      isOffline(error) ? offlineMessage : '$error';
}
