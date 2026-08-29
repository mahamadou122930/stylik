import 'package:supabase_flutter/supabase_flutter.dart';

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
  /// Les refus de la base arrivent en `PostgrestException`, dont le
  /// `toString()` déverse le code, les détails et l'indice — trois lignes de
  /// jargon pour un gérant de salon. Or ces refus portent presque toujours un
  /// message utile : nos fonctions SQL lèvent leurs exceptions en français
  /// (« Montant supérieur au dû restant (1 050 F) »), et c'est cette phrase-là
  /// qu'il faut montrer.
  ///
  /// Seuls deux cas techniques sont traduits, parce que leur message d'origine
  /// ne dit rien à personne : la fonction absente et le refus de policy.
  static String humanize(Object? error) {
    if (isOffline(error)) return offlineMessage;

    if (error is PostgrestException) {
      // PGRST202 : la fonction n'existe pas dans la base. C'est une migration
      // qui n'a pas été appliquée, pas une erreur de saisie.
      if (error.code == 'PGRST202') {
        return 'Action indisponible : la base de données doit être mise à '
            'jour.';
      }

      // Une policy a refusé l'écriture. Le texte de PostgreSQL parle de
      // « row-level security policy », ce qui n'aide personne sur le terrain.
      if (error.message.toLowerCase().contains('row-level security')) {
        return "Vous n'avez pas les droits pour cette action.";
      }

      return error.message;
    }

    return '$error';
  }
}
