import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/registration_draft.dart';
import 'role_selection_page.dart';

/// 1.3 — Inscription salon, étape 1/2 : identité du salon et compte du gérant.
///
/// La maquette ne montre que les champs du salon ; l'email et le mot de passe
/// sont regroupés en dessous, dans le même écran défilant, car Supabase ne peut
/// pas créer le compte sans eux.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  static const routeName = '/register';

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _salonName = TextEditingController();
  final _salonPhone = TextEditingController();
  final _salonAddress = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  File? _logo;

  @override
  void dispose() {
    _salonName.dispose();
    _salonPhone.dispose();
    _salonAddress.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pushNamed(
      RoleSelectionPage.routeName,
      arguments: RegistrationDraft(
        salonName: _salonName.text.trim(),
        salonPhone: _salonPhone.text.trim(),
        salonAddress: _salonAddress.text.trim(),
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        logo: _logo,
      ),
    );
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Requis' : null;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Votre salon',
      topBar: const AppStepHeader(step: 1, stepCount: 2),
      bodyPadding: const EdgeInsets.fromLTRB(26, 8, 26, 20),
      footer: AppButton(label: 'Continuer', onPressed: _continue),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Votre salon',
              style: AppTypography.sora(
                26,
                FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 22),
            LogoSlot(
              file: _logo,
              onPicked: (file) => setState(() => _logo = file),
            ),
            const SizedBox(height: 22),
            AppInput(
              label: 'Nom du salon',
              hint: 'L\'Atelier Coiffure',
              controller: _salonName,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 16),
            AppInput.phone(
              controller: _salonPhone,
              hint: '+223 76 12 34 56',
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 16),
            AppInput(
              label: 'Adresse',
              hint: 'Rue 224, Hamdallaye ACI 2000, Bamako',
              controller: _salonAddress,
              prefixIcon: Icons.place_outlined,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 26),
            const AppSectionTitle('Votre compte'),
            AppInput(
              label: 'Nom complet',
              hint: 'Fatoumata Traoré',
              controller: _fullName,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 16),
            AppInput(
              label: 'Email',
              hint: 'fatoumata@latelier.ml',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || !value.contains('@'))
                  ? 'Email invalide'
                  : null,
            ),
            const SizedBox(height: 16),
            AppInput(
              label: 'Mot de passe',
              controller: _password,
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (value) =>
                  (value == null || value.length < 6) ? '6 caractères min.' : null,
            ),
          ],
        ),
      ),
    );
  }
}
