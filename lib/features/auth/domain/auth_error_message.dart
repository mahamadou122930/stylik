import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduit une erreur d'authentification Supabase en message affichable.
///
/// Les exceptions brutes (`AuthApiException(message: ..., statusCode: ...)`)
/// n'ont aucun sens pour un gérant de salon.
/// [fallback] remplace le message brut quand le refus vient d'un trigger de la
/// base : Supabase le remonte en `unexpected_failure` (« Database error saving
/// new user »), sans jamais faire remonter le texte de l'exception SQL.
String authErrorMessage(Object? error, {String? fallback}) {
  if (error is AuthApiException) {
    if (error.code == 'unexpected_failure' && fallback != null) {
      return fallback;
    }
    switch (error.code) {
      case 'email_address_invalid':
        return "Cette adresse email est refusée. Utilisez une adresse "
            "professionnelle ou personnelle valide (gmail, outlook…).";
      case 'user_already_exists':
      case 'email_exists':
        return 'Un compte existe déjà avec cette adresse email.';
      case 'weak_password':
        return 'Mot de passe trop faible : 6 caractères minimum.';
      case 'over_email_send_rate_limit':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      case 'invalid_credentials':
        return 'Email ou mot de passe incorrect.';
      default:
        return error.message;
    }
  }

  if (error is PostgrestException) return error.message;
  if (error is AuthException) return error.message;

  return 'Une erreur est survenue. Vérifiez votre connexion et réessayez.';
}
