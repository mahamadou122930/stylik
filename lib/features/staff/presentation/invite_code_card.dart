import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../settings/presentation/settings_providers.dart';

/// Code d'invitation du salon (maquette 4.5) — à dicter à un employé dont la
/// fiche vient d'être créée, pour qu'il crée son compte depuis « Rejoindre un
/// salon ». Le code est celui du salon : c'est l'email de la fiche qui
/// identifie la personne.
class InviteCodeCard extends ConsumerWidget {
  const InviteCodeCard({super.key, required this.message});

  /// Explication sous le code — elle change selon l'écran qui l'affiche.
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currentSalonProvider).valueOrNull?.inviteCode;

    return AppCard(
      color: AppColors.tintGreenSoft,
      borderColor: AppColors.tintGreenBorder,
      shadow: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  code ?? '••••••',
                  style: AppTypography.sora(
                    26,
                    FontWeight.w800,
                    letterSpacing: 6,
                    color:
                        code == null ? AppColors.textFaint : AppColors.textPrimary,
                  ),
                ),
              ),
              if (code != null)
                AppPillButton(
                  label: 'Copier',
                  color: AppColors.primary,
                  background: AppColors.tintGreen,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copié.')),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.manrope(
              12.5,
              FontWeight.w500,
              color: AppColors.textBody,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
