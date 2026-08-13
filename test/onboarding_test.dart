import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/core/theme/app_theme.dart';
import 'package:stylik/core/widgets/widgets.dart';
import 'package:stylik/features/auth/domain/registration_draft.dart';
import 'package:stylik/features/auth/domain/salon_invite.dart';
import 'package:stylik/features/auth/presentation/join_salon_page.dart';
import 'package:stylik/features/auth/presentation/login_page.dart';
import 'package:stylik/features/auth/presentation/register_page.dart';
import 'package:stylik/features/auth/presentation/role_selection_page.dart';
import 'package:stylik/features/auth/presentation/signup_choice_page.dart';
import 'package:stylik/features/auth/presentation/welcome_page.dart';

/// Les écrans du tunnel d'entrée sont rendus au format exact de la maquette
/// (390 × 844) : tout débordement signale un écart de mise en page.
void main() {
  const draft = RegistrationDraft(
    salonName: 'L\'Atelier Coiffure',
    salonPhone: '+221 77 123 45 67',
    salonAddress: 'Rue 10, Almadies, Dakar',
    fullName: 'Léa Fall',
    email: 'lea@latelier.sn',
    password: 'motdepasse',
  );

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.pump();
  }

  testWidgets('1.1 Bienvenue affiche le héros et les deux portes d\'entrée',
      (tester) async {
    await pumpScreen(tester, const WelcomePage());

    expect(find.text('L\'Atelier'), findsOneWidget);
    expect(
      find.text('La gestion complète de votre salon, dans une seule app.'),
      findsOneWidget,
    );
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('J\'ai déjà un compte'), findsOneWidget);
  });

  testWidgets('1.2 Connexion suit les libellés de la maquette', (tester) async {
    await pumpScreen(tester, const LoginPage());

    expect(find.text('L\'Atelier'), findsOneWidget);
    expect(
      find.text('La gestion de votre salon, simplifiée'),
      findsOneWidget,
    );
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    // Le lien d'inscription est un fragment de `Text.rich`, pas un `Text`.
    expect(
      find.textContaining('Créer un compte', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('1.2b Créer un compte aiguille vers les deux parcours',
      (tester) async {
    await pumpScreen(tester, const SignupChoicePage());

    expect(find.text('Je crée mon salon'), findsOneWidget);
    expect(find.text('Vous êtes le gérant'), findsOneWidget);
    expect(find.text('Je rejoins un salon'), findsOneWidget);
    expect(
      find.text('Coiffeur ou réceptionniste · avec code'),
      findsOneWidget,
    );
  });

  testWidgets('1.2c Rejoindre un salon attend un code avant de s\'ouvrir',
      (tester) async {
    await pumpScreen(tester, const JoinSalonPage());

    expect(find.text('Code d\'invitation'), findsOneWidget);
    expect(
      find.text('$inviteCodeLength caractères, communiqués par votre gérant.'),
      findsOneWidget,
    );
    // Une case par caractère, toutes vides au départ.
    expect(find.text('•'), findsNWidgets(inviteCodeLength));

    // Tant qu'aucun salon n'est reconnu, l'inscription reste fermée.
    final cta = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Rejoindre le salon'),
    );
    expect(cta.onPressed, isNull);
  });

  testWidgets('1.3 Inscription est l\'étape 1/2 et collecte le salon',
      (tester) async {
    await pumpScreen(tester, const RegisterPage());

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Votre salon'), findsOneWidget);
    expect(find.text('Logo'), findsOneWidget);
    expect(find.text('Nom du salon'), findsOneWidget);
    expect(find.text('Adresse'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);
  });

  testWidgets('1.4 Rôle est l\'étape 2/2 et ferme le parcours', (tester) async {
    await pumpScreen(tester, const RoleSelectionPage(draft: draft));

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Votre rôle'), findsOneWidget);
    expect(find.text('Chaque membre voit ce dont il a besoin.'), findsOneWidget);
    expect(find.text('Gérant'), findsOneWidget);
    expect(find.text('Entrer dans l\'app'), findsOneWidget);
  });
}
