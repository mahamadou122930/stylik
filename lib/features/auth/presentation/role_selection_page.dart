import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/providers.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/auth_error_message.dart';
import '../domain/registration_draft.dart';
import '../domain/user_role.dart';
import 'auth_providers.dart';

/// Sélecteur de rôle (Gérant, Coiffeur, Réceptionniste).
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showLabel = true,
  });

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  /// `false` sur l'écran 1.4, où le titre de l'écran tient déjà ce rôle.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 7),
            child: Text(
              'Rôle dans le salon',
              style: AppTypography.sora(
                12.5,
                FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
          ),
        for (final role in UserRole.values) ...[
          AppCard(
            onTap: () => onChanged(role),
            radius: 18,
            shadow: false,
            color: AppColors.surface,
            borderColor:
                selected == role ? AppColors.accent : AppColors.border,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildIconTile(role),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.label,
                        style: AppTypography.sora(16, FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _descriptionFor(role),
                        style: AppTypography.manrope(
                          12.5,
                          FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        selected == role ? AppColors.accent : Colors.transparent,
                    border: selected == role
                        ? null
                        : Border.all(color: AppColors.borderStrong, width: 2),
                  ),
                  child: selected == role
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildIconTile(UserRole role) {
    final (background, color, iconData) = switch (role) {
      UserRole.gerant => (
          AppColors.primary,
          Colors.white,
          Icons.workspace_premium_rounded
        ),
      UserRole.coiffeur => (
          AppColors.tintBlue,
          AppColors.blue,
          Icons.content_cut_rounded
        ),
      UserRole.receptionniste => (
          AppColors.tintAmber,
          AppColors.amber,
          Icons.calendar_today_rounded
        ),
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(iconData, size: 24, color: color),
    );
  }

  String _descriptionFor(UserRole role) => switch (role) {
        UserRole.gerant => 'Accès complet : finance, staff, réglages',
        UserRole.coiffeur => 'Son planning, ses clients, ses commissions',
        UserRole.receptionniste => 'Agenda, clients et caisse',
      };
}

/// 1.4 — Sélection du rôle, étape 2/2 : dernier écran avant l'entrée dans
/// l'app. C'est ici que le salon, le compte et le logo sont réellement créés.
class RoleSelectionPage extends ConsumerStatefulWidget {
  const RoleSelectionPage({super.key, required this.draft});

  static const routeName = '/role';

  final RegistrationDraft draft;

  @override
  ConsumerState<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends ConsumerState<RoleSelectionPage> {
  late UserRole _role = widget.draft.role;

  Future<void> _submit() async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .registerSalon(widget.draft.copyWith(role: _role));

    if (!mounted) return;

    if (!success) {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(error))),
      );
      return;
    }

    final navigator = Navigator.of(context);
    if (ref.read(currentSessionProvider) != null) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salon créé. Confirmez votre email pour vous connecter.'),
        ),
      );
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AppScreen(
      title: 'Votre rôle',
      topBar: const AppStepHeader(step: 2, stepCount: 2),
      bodyPadding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
      footer: AppButton(
        label: 'Entrer dans l\'app',
        isLoading: isLoading,
        onPressed: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Votre rôle',
            style: AppTypography.sora(26, FontWeight.w800, letterSpacing: -0.7),
          ),
          const SizedBox(height: 6),
          Text(
            'Chaque membre voit ce dont il a besoin.',
            style: AppTypography.manrope(
              14,
              FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          RoleSelector(
            selected: _role,
            showLabel: false,
            onChanged: (role) => setState(() => _role = role),
          ),
          const SizedBox(height: 16),
          const AppCallout(
            message:
                'Le gérant peut modifier les rôles et permissions à tout moment dans les réglages.',
          ),
        ],
      ),
    );
  }
}
