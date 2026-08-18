import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/core/utils/error_messages.dart';
import 'package:stylik/core/widgets/widgets.dart';

/// Traduction des erreurs techniques. Un gérant de salon ne doit pas lire
/// « errno = 7 » : il doit comprendre que sa connexion est coupée.
void main() {
  group('détection d\'une coupure réseau', () {
    test('reconnaît l\'erreur remontée par Supabase', () {
      // Le message réellement observé sur l'émulateur, enveloppé par la
      // couche d'authentification.
      const raw =
          'AuthRetryableFetchException(message: ClientException with '
          'SocketException: Failed host lookup: '
          "'dmtbqknxzilrzsvufzcx.supabase.co' (OS Error: No address associated "
          'with hostname, errno = 7), statusCode: null)';

      expect(ErrorMessages.isOffline(raw), isTrue);
      expect(ErrorMessages.humanize(raw), ErrorMessages.offlineMessage);
    });

    test('reconnaît les formes usuelles', () {
      const cases = [
        'SocketException: Connection refused',
        'ClientException: Connection closed before full header was received',
        'Failed host lookup: api.example.com',
        'Network is unreachable',
        'TimeoutException after 0:00:30.000000',
      ];

      for (final raw in cases) {
        expect(ErrorMessages.isOffline(raw), isTrue, reason: raw);
      }
    });

    test('reconnaît une SocketException typée', () {
      expect(ErrorMessages.isOffline(const SocketException('échec')), isTrue);
    });

    test('laisse passer les autres erreurs', () {
      // Un refus métier garde son texte : c'est la seule piste exploitable
      // pour diagnostiquer, et le masquer nous a déjà coûté cher.
      const raw =
          'PostgrestException(message: column does not exist, '
          'code: 42703)';

      expect(ErrorMessages.isOffline(raw), isFalse);
      expect(ErrorMessages.humanize(raw), raw);
    });

    test('une erreur nulle n\'est pas une coupure', () {
      expect(ErrorMessages.isOffline(null), isFalse);
    });
  });

  group('affichage', () {
    Widget host(String message) => MaterialApp(
      home: Scaffold(
        body: AppErrorState(message: message, onRetry: () {}),
      ),
    );

    testWidgets('une coupure affiche un message humain', (tester) async {
      await tester.pumpWidget(
        host('ClientException with SocketException: Failed host lookup'),
      );

      expect(find.text('Pas de connexion'), findsOneWidget);
      expect(find.text(ErrorMessages.offlineMessage), findsOneWidget);
      // La trace technique ne doit pas atteindre l'écran.
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('les autres erreurs gardent leur texte', (tester) async {
      await tester.pumpWidget(host('Montant supérieur au disponible'));

      expect(find.text('Une erreur est survenue'), findsOneWidget);
      expect(find.text('Montant supérieur au disponible'), findsOneWidget);
    });
  });
}
