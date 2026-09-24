import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/subscription_plan.dart';
import '../domain/subscription_request.dart';
import 'settings_providers.dart';
import 'subscription_page.dart';

/// Où et comment payer une demande d'activation.
///
/// L'écran lit la demande en attente plutôt que de la recevoir en argument :
/// le gérant qui revient plus tard depuis l'écran d'abonnement retrouve la
/// même référence et le même numéro, sans redéposer de demande.
class PaymentInstructionsPage extends ConsumerWidget {
  const PaymentInstructionsPage({super.key});

  static const routeName = '/settings/subscription/payment';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestAsync = ref.watch(pendingSubscriptionRequestProvider);
    final accounts = ref.watch(paymentAccountsProvider).valueOrNull ?? const [];

    return AppScreen(
      title: 'Paiement de votre formule',
      footer: AppButton(
        label: 'Terminé',
        height: 56,
        onPressed: () => Navigator.of(context).popUntil(
          (route) =>
              route.settings.name == SubscriptionPage.routeName ||
              route.isFirst,
        ),
      ),
      child: requestAsync.when(
        loading: () => const AppLoader(compact: true),
        error: (_, _) => const _Message(
          icon: LucideIcons.wifiOff,
          text:
              'Impossible de relire votre demande. Vérifiez votre connexion, '
              'puis rouvrez cet écran.',
        ),
        data: (request) => request == null
            ? const _Message(
                icon: LucideIcons.circleCheck,
                text:
                    "Aucune demande en attente : votre dernière demande a été "
                    'honorée, ou remplacée.',
              )
            : _Instructions(request: request, accounts: accounts),
      ),
    );
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions({required this.request, required this.accounts});

  final SubscriptionRequest request;
  final List<PaymentAccount> accounts;

  @override
  Widget build(BuildContext context) {
    // Le compte du moyen choisi, sinon tous : un gérant qui n'a rien choisi
    // doit quand même savoir où payer.
    final chosen = accounts.where((a) => a.method == request.method).toList();
    final shown = chosen.isNotEmpty ? chosen : accounts;
    final amount = Formatters.fcfa(request.amountFcfa);
    final cycle = request.billingCycle == BillingCycle.annual
        ? '12 mois'
        : '1 mois';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.tintGreenSoft,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(color: AppColors.tintGreenBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.circleCheck,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demande enregistrée',
                      style: AppTypography.manrope(
                        13,
                        FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${request.planName} · $cycle',
                style: AppTypography.manrope(
                  13.5,
                  FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount,
                style: AppTypography.sora(
                  26,
                  FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const AppSectionLabel(
          'Référence à indiquer',
          padding: EdgeInsets.fromLTRB(2, 20, 2, 10),
        ),
        _ReferenceTile(reference: request.reference),
        const AppSectionLabel(
          'Comment payer',
          padding: EdgeInsets.fromLTRB(2, 20, 2, 10),
        ),
        if (shown.isEmpty)
          const _Step(
            number: 1,
            text:
                "Notre équipe vous contacte pour le paiement. Gardez votre "
                'référence : elle permet de rattacher votre règlement à votre '
                'salon.',
          )
        else ...[
          _Step(
            number: 1,
            text: shown.length == 1
                ? 'Envoyez $amount par ${shown.first.method} au numéro '
                      'ci-dessous.'
                : "Envoyez $amount sur l'un des comptes ci-dessous.",
          ),
          for (final account in shown) _AccountTile(account: account),
          _Step(
            number: 2,
            text:
                'Indiquez la référence ${request.reference} dans le message '
                'du transfert.',
          ),
          const _Step(
            number: 3,
            text:
                'Votre formule est activée dès réception du paiement. Vous '
                "n'avez rien d'autre à faire.",
          ),
        ],
      ],
    );
  }
}

/// La référence, en grand, avec de quoi la copier.
class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              reference,
              style: AppTypography.sora(
                20,
                FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: reference));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Référence copiée.')),
              );
            },
            icon: const Icon(LucideIcons.copy, size: 16),
            label: const Text('Copier'),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final PaymentAccount account;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 38, bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(
              LucideIcons.smartphone,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${account.method} · ${account.accountNumber}',
                    style: AppTypography.sora(
                      14,
                      FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Le nom affiché par l'opérateur mobile au moment de
                  // l'envoi : le gérant vérifie qu'il paie la bonne personne.
                  if (account.holderName != null)
                    Text(
                      'Au nom de ${account.holderName}',
                      style: AppTypography.manrope(
                        12,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
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

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.tintGreen,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppTypography.sora(
                12,
                FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: AppTypography.manrope(
                  13.5,
                  FontWeight.w500,
                  color: AppColors.textBody,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.manrope(
              13.5,
              FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
