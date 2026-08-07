import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/auth_error_message.dart';
import 'auth_providers.dart';
import 'register_page.dart';

/// Connexion du personnel du salon.
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: const AppLogo(size: 84, radius: 22),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Bon retour',
                      textAlign: TextAlign.center,
                      style: AppTypography.sora(
                        28,
                        FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connectez-vous pour gérer votre salon.',
                      textAlign: TextAlign.center,
                      style: AppTypography.manrope(
                        14.5,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    AppInput(
                      label: 'Email ou téléphone',
                      hint: 'lea@latelier.sn',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.email_outlined,
                      validator: (value) =>
                          (value == null || !value.contains('@'))
                              ? 'Email invalide'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Mot de passe',
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
                          color: AppColors.textFaint,
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 6)
                          ? '6 caractères minimum'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _resetPassword,
                        child: Text(
                          'Mot de passe oublié ?',
                          style: AppTypography.manrope(
                            12.5,
                            FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    AppButton(
                      label: 'Se connecter',
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => Navigator.of(context)
                          .pushNamed(RegisterPage.routeName),
                      child: Text.rich(
                        TextSpan(
                          text: 'Pas encore de salon ? ',
                          style: AppTypography.manrope(
                            13.5,
                            FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: 'Créer un compte',
                              style: AppTypography.manrope(
                                13.5,
                                FontWeight.w700,
                                color: AppColors.primary,
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
          ),
        ),
      ),
    );
  }
}
