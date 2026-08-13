import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/providers.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/auth_error_message.dart';
import '../domain/salon_invite.dart';
import 'auth_providers.dart';

/// 1.2b — Rejoindre un salon avec le code d'invitation du gérant.
///
/// Le code désigne le salon ; le rattachement, lui, se fait sur l'email : le
/// gérant a créé la fiche employé avec cette adresse, et c'est elle que
/// l'inscription réclame. Sans fiche correspondante, le serveur refuse — le
/// code seul n'ouvre aucune porte.
class JoinSalonPage extends ConsumerStatefulWidget {
  const JoinSalonPage({super.key});

  static const routeName = '/join';

  @override
  ConsumerState<JoinSalonPage> createState() => _JoinSalonPageState();
}

class _JoinSalonPageState extends ConsumerState<JoinSalonPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Salon reconnu derrière le code saisi, `null` tant qu'il ne l'est pas.
  SalonInvite? _invite;
  bool _lookingUp = false;

  /// Vrai dès qu'un code complet a été cherché sans rien trouver — sert à ne
  /// montrer « Code inconnu » qu'après une vraie recherche, pas pendant la
  /// frappe des cinq premiers caractères.
  bool _lookupFailed = false;

  @override
  void dispose() {
    _code.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _onCodeChanged(String value) async {
    final code = value.trim().toUpperCase();

    if (code.length < inviteCodeLength) {
      if (_invite != null || _lookupFailed) {
        setState(() {
          _invite = null;
          _lookupFailed = false;
        });
      }
      return;
    }

    if (_invite?.code == code) return;

    setState(() {
      _lookingUp = true;
      _invite = null;
      _lookupFailed = false;
    });

    SalonInvite? found;
    try {
      found = await ref.read(authRepositoryProvider).findSalonByInviteCode(code);
    } catch (_) {
      found = null;
    }

    if (!mounted) return;
    // Le code a pu changer pendant l'appel : une réponse en retard ne doit pas
    // écraser la saisie courante.
    if (_code.text.trim().toUpperCase() != code) return;

    setState(() {
      _lookingUp = false;
      _invite = found;
      _lookupFailed = found == null;
    });
  }

  Future<void> _submit() async {
    final invite = _invite;
    if (invite == null || !_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final success = await ref.read(authControllerProvider.notifier).joinSalon(
          code: invite.code,
          email: _email.text.trim(),
          password: _password.text,
          fullName: _fullName.text.trim(),
        );

    if (!mounted) return;

    if (!success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            authErrorMessage(
              ref.read(authControllerProvider).error,
              fallback: 'Aucune fiche employé n\'attend cet email chez '
                  '${invite.salonName}. Demandez à votre gérant de vous '
                  'ajouter à l\'équipe.',
            ),
          ),
        ),
      );
      return;
    }

    if (ref.read(currentSessionProvider) == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Compte créé. Confirmez votre email pour vous connecter.',
          ),
        ),
      );
    }
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final invite = _invite;

    return AppScreen(
      title: 'Rejoindre un salon',
      bodyPadding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
      footer: AppButton(
        label: invite == null
            ? 'Rejoindre le salon'
            : 'Rejoindre ${invite.salonName}',
        isLoading: isLoading,
        onPressed: invite == null ? null : _submit,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel('Code d\'invitation'),
            InviteCodeField(controller: _code, onChanged: _onCodeChanged),
            const SizedBox(height: 6),
            Text(
              '$inviteCodeLength caractères, communiqués par votre gérant.',
              style: AppTypography.manrope(
                12,
                FontWeight.w500,
                color: AppColors.textFaint,
              ),
            ),
            if (_lookingUp || invite != null || _lookupFailed) ...[
              const SizedBox(height: 16),
              _lookupResult(invite),
            ],
            const SizedBox(height: 20),
            const _FieldLabel('Votre nom'),
            AppInput(
              hint: 'Karim Sy',
              controller: _fullName,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Requis'
                  : null,
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Email'),
            AppInput(
              hint: 'karim@latelier.sn',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || !value.contains('@'))
                  ? 'Email invalide'
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              'Utilisez l\'adresse que votre gérant a saisie sur votre fiche.',
              style: AppTypography.manrope(
                12,
                FontWeight.w500,
                color: AppColors.textFaint,
              ),
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Mot de passe'),
            AppInput(
              controller: _password,
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (value) => (value == null || value.length < 6)
                  ? '6 caractères minimum'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _lookupResult(SalonInvite? invite) {
    if (_lookingUp) {
      return AppCard(
        color: AppColors.tintGreenSoft,
        borderColor: AppColors.tintGreenBorder,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 13),
            Text(
              'Recherche du salon…',
              style: AppTypography.manrope(
                13.5,
                FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (invite == null) {
      return const AppCallout(
        message: 'Code inconnu. Vérifiez les six caractères auprès de votre '
            'gérant.',
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
        background: AppColors.tintDanger,
        borderColor: AppColors.dangerBorder,
      );
    }

    return AppCard(
      color: AppColors.tintGreenSoft,
      borderColor: AppColors.tintGreenBorder,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: AppGlyph(size: 24, color: Colors.white),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salon reconnu',
                  style: AppTypography.manrope(
                    11.5,
                    FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  invite.salonName,
                  style: AppTypography.sora(15, FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.check_circle_rounded,
            size: 22,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

/// Libellé de champ de la maquette — Sora 650 / 12.5.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: AppTypography.sora(
          12.5,
          FontWeight.w600,
          color: AppColors.textBody,
          wght: 650,
        ),
      ),
    );
  }
}

/// Saisie du code d'invitation, une case par caractère.
///
/// Les cases ne sont qu'un décor : la frappe passe par un unique champ
/// transparent posé au-dessus, seul moyen d'obtenir un collage, une correction
/// ou un retour arrière corrects avec un clavier mobile.
class InviteCodeField extends StatefulWidget {
  const InviteCodeField({
    super.key,
    required this.controller,
    this.onChanged,
    this.length = inviteCodeLength,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int length;

  @override
  State<InviteCodeField> createState() => _InviteCodeFieldState();
}

class _InviteCodeFieldState extends State<InviteCodeField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            final code = value.text;
            return Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: 9),
                  Expanded(child: _box(code, i)),
                ],
              ],
            );
          },
        ),
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            maxLength: widget.length,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            keyboardType: TextInputType.visiblePassword,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              _UpperCaseFormatter(),
            ],
            // Le champ ne sert qu'à capter la frappe : le curseur et le texte
            // sont rendus par les cases en dessous.
            showCursor: false,
            cursorWidth: 0,
            style: const TextStyle(color: Colors.transparent, fontSize: 24),
            decoration: const InputDecoration(
              counterText: '',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _box(String code, int index) {
    final filled = index < code.length;
    // La case active suit le point d'insertion, et seulement quand le clavier
    // est ouvert : sinon le champ paraîtrait en cours de saisie au repos.
    final isActive = _focusNode.hasFocus && index == code.length;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.accent : AppColors.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        filled ? code[index] : '•',
        style: AppTypography.sora(
          24,
          FontWeight.w800,
          color: filled ? AppColors.textPrimary : AppColors.textFaint,
        ),
      ),
    );
  }
}

/// Le code est stocké en majuscules : `textCapitalization` n'est qu'une
/// suggestion au clavier, que les claviers physiques et le collage ignorent.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
