import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/auth_error_message.dart';
import 'auth_providers.dart';
import 'signup_choice_page.dart';

/// Connexion du personnel du salon — écran sombre pleine page de la maquette.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  static const routeName = '/login';

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final success = await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text.trim(),
          password: _password.text,
        );

    if (!mounted) return;

    if (!success) {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error))),
      );
      return;
    }

    navigator.popUntil((route) => route.isFirst);
  }

  /// Envoie le lien de réinitialisation à l'adresse déjà saisie.
  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (!email.contains('@')) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Saisissez d\'abord votre email.'),
        ),
      );
      return;
    }

    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Lien de réinitialisation envoyé à $email.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Envoi impossible : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.textPrimary,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                // Le bloc d'identification est centré et le pied reste collé en
                // bas : c'est la mise en page de la maquette, et elle tient
                // aussi quand le clavier réduit la hauteur disponible.
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          26,
                          20,
                          26,
                          MediaQuery.paddingOf(context).bottom + 26,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _identity()),
                            const SizedBox(height: 28),
                            AppButton(
                              label: 'Se connecter',
                              isLoading: isLoading,
                              height: 56,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: () => Navigator.of(context)
                                  .pushNamed(SignupChoicePage.routeName),
                              child: Text.rich(
                                TextSpan(
                                  text: 'Pas de compte ? ',
                                  style: AppTypography.manrope(
                                    13,
                                    FontWeight.w600,
                                    color: Colors.white54,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Créer un compte',
                                      style: AppTypography.manrope(
                                        13,
                                        FontWeight.w600,
                                        color: AppColors.mint,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Marque, champs et lien d'oubli — le bloc centré de l'écran.
  Widget _identity() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Center(
              child: AppGlyph(size: 36, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'L\'Atelier',
          textAlign: TextAlign.center,
          style: AppTypography.sora(
            28,
            FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'La gestion de votre salon, simplifiée',
          textAlign: TextAlign.center,
          style: AppTypography.manrope(
            14,
            FontWeight.w500,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 28),
        AppInput(
          dark: true,
          hint: 'fatoumata@latelier.ml',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          prefixIcon: Icons.email_outlined,
          validator: (value) => (value == null || !value.contains('@'))
              ? 'Email invalide'
              : null,
        ),
        const SizedBox(height: 12),
        AppInput(
          dark: true,
          hint: '••••••••',
          controller: _password,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          prefixIcon: Icons.lock_outline_rounded,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 19,
              color: Colors.white60,
            ),
          ),
          validator: (value) =>
              (value == null || value.length < 6) ? '6 caractères minimum' : null,
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _resetPassword,
            child: Text(
              'Mot de passe oublié ?',
              style: AppTypography.manrope(
                12.5,
                FontWeight.w700,
                color: AppColors.mint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
