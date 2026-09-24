import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/subscription.dart';
import 'plan_selection_page.dart';
import 'settings_providers.dart';

/// Le salon est-il en lecture seule faute d'abonnement à jour ?
///
/// La règle vit en base, dans `salon_subscription_is_active` : c'est elle qui
/// fait foi, et c'est elle qui refuse l'écriture quoi qu'en dise le client.
/// Ce drapeau ne sert qu'à l'annoncer avant d'essayer, plutôt que de laisser
/// un gérant remplir un ticket entier pour se voir refuser à l'encaissement.
///
/// Tant que l'abonnement n'est pas lu, le salon n'est pas verrouillé : une
/// lecture en cours ou hors ligne ne doit pas fermer la caisse.
final subscriptionLockedProvider = Provider<bool>((ref) {
  final subscription = ref.watch(subscriptionProvider).valueOrNull;
  if (subscription == null) return false;
  return !subscription.isActive;
});

/// Barre permanente rappelant que le salon ne peut plus rien enregistrer.
///
/// Elle s'affiche pour toute l'équipe : c'est le salon qui n'est plus
/// abonné, pas une personne. Sans cela, la caisse continuerait de tourner
/// depuis le compte d'un coiffeur.
class SubscriptionLockBanner extends ConsumerWidget {
  const SubscriptionLockBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(subscriptionLockedProvider)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        onTap: () =>
            Navigator.of(context).pushNamed(PlanSelectionPage.routeName),
        radius: 18,
        shadow: false,
        color: AppColors.tintDanger,
        borderColor: AppColors.dangerBorder,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(LucideIcons.lock, size: 22, color: AppColors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Salon en lecture seule',
                    style: AppTypography.sora(
                      14,
                      FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Votre abonnement est arrivé à échéance. Tout reste '
                    'consultable, mais plus rien ne peut être enregistré.',
                    style: AppTypography.manrope(
                      12,
                      FontWeight.w500,
                      color: AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vérifie que le salon peut encore écrire, et l'explique sinon.
///
/// Rend `true` quand l'action peut suivre son cours. Quand elle ne le peut
/// pas, ouvre la feuille qui l'explique et rend `false` : à l'appelant de
/// s'arrêter là.
Future<bool> ensureSubscriptionActive(
  BuildContext context,
  WidgetRef ref,
) async {
  // On attend la lecture au lieu de consulter le drapeau tel quel : un écran
  // ouvert avant que l'abonnement ne soit lu verrait `null`, donc « pas
  // verrouillé », et laisserait partir une écriture que la base refusera.
  // Riverpod garde le résultat en cache : l'attente ne coûte qu'au premier
  // appel.
  final Subscription? subscription;
  try {
    subscription = await ref.read(subscriptionProvider.future);
  } catch (_) {
    // Hors ligne, ou lecture impossible. Bloquer ici fermerait la caisse sur
    // une panne de réseau ; la base tranchera de toute façon au moment de
    // l'écriture, et son refus est traduit en français.
    return true;
  }

  if (subscription == null || subscription.isActive) return true;
  if (!context.mounted) return false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _LockedSheet(),
  );

  return false;
}

class _LockedSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.tintDanger,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                LucideIcons.lock,
                size: 26,
                color: AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Salon en lecture seule',
            textAlign: TextAlign.center,
            style: AppTypography.sora(
              20,
              FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Votre abonnement est arrivé à échéance. Vos rendez-vous, vos '
            'clients et vos chiffres restent consultables et exportables — '
            'mais aucune nouvelle saisie n\'est possible tant qu\'une formule '
            'n\'est pas activée.',
            textAlign: TextAlign.center,
            style: AppTypography.manrope(
              13.5,
              FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          AppButton(
            label: 'Choisir un plan',
            height: 52,
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(PlanSelectionPage.routeName);
            },
          ),
          const SizedBox(height: 10),
          AppButton.outline(
            label: 'Fermer',
            height: 48,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
