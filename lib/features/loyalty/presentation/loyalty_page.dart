import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../clients/domain/client.dart';
import '../domain/loyalty_campaign.dart';
import 'loyalty_providers.dart';
import 'promotions_page.dart';
import 'reminders_page.dart';

/// 9.1 — Programme de fidélité : carte client, paliers, récompenses.
class LoyaltyPage extends ConsumerWidget {
  const LoyaltyPage({super.key});

  static const routeName = '/loyalty';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(loyaltyCardClientProvider);
    final rewards = ref.watch(rewardsProvider);
    final topClients = ref.watch(topClientsProvider);

    return AppScreen(
      title: 'Fidélité',
      showBack: false,
      action: AppIconButton(
        icon: Icons.campaign_rounded,
        filled: true,
        onTap: () => Navigator.of(context).pushNamed(PromotionsPage.routeName),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (card != null) _LoyaltyCard(client: card),
          const AppSectionTitle('Récompenses disponibles'),
          rewards.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              compact: true,
              onRetry: () => ref.invalidate(rewardsProvider),
            ),
            data: (items) => items.isEmpty
                ? const AppEmptyState(
                    compact: true,
                    title: 'Aucune récompense',
                    message: 'Créez les récompenses échangeables par vos '
                        'clientes contre leurs points.',
                    icon: Icons.card_giftcard_rounded,
                  )
                : Column(
                    children: [
                      for (final reward in items) ...[
                        _RewardTile(
                          reward: reward,
                          points: card?.loyaltyPoints ?? 0,
                          onRedeem: card == null
                              ? null
                              : () async {
                                  await ref
                                      .read(loyaltyRepositoryProvider)
                                      .redeemReward(
                                        clientId: card.id,
                                        reward: reward,
                                      );
                                  ref.invalidate(topClientsProvider);
                                },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
          const AppSectionTitle('Marketing'),
          AppListCard(
            children: [
              AppListRow(
                label: 'Promotions & offres',
                subtitle: 'Campagnes actives et planifiées',
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                leading: const AppIconTile(
                  icon: Icons.local_offer_rounded,
                  color: AppColors.violet,
                  background: AppColors.tintViolet,
                ),
                trailing: const AppChevron(),
                onTap: () =>
                    Navigator.of(context).pushNamed(PromotionsPage.routeName),
              ),
              AppListRow(
                label: 'Rappels automatiques',
                subtitle: 'SMS & WhatsApp',
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                leading: const AppIconTile(icon: Icons.sms_rounded),
                trailing: const AppChevron(),
                onTap: () =>
                    Navigator.of(context).pushNamed(RemindersPage.routeName),
              ),
            ],
          ),
          const AppSectionTitle('Meilleurs clients'),
          topClients.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              compact: true,
              onRetry: () => ref.invalidate(topClientsProvider),
            ),
            data: (clients) => clients.isEmpty
                ? const AppEmptyState(
                    compact: true,
                    title: 'Aucun client fidèle',
                    icon: Icons.emoji_events_outlined,
                  )
                : AppListCard(
                    children: [
                      for (final client in clients.take(6))
                        AppListRow(
                          label: client.fullName,
                          subtitle:
                              LoyaltyTier.forPoints(client.loyaltyPoints).label,
                          strong: true,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          leading: AppAvatar(
                            initials: client.initials,
                            size: 36,
                          ),
                          trailing: AppBadge(
                            label: '${client.loyaltyPoints} pts',
                            color: AppColors.primary,
                            background: AppColors.tintGreen,
                          ),
                          onTap: () => ref
                              .read(loyaltyClientProvider.notifier)
                              .state = client,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Carte de fidélité sombre en tête d'écran.
class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final tier = LoyaltyTier.forPoints(client.loyaltyPoints);
    final next = tier.next;
    final progress = next == null
        ? 1.0
        : (client.loyaltyPoints - tier.threshold) /
            (next.threshold - tier.threshold);

    return AppGradientCard(
      gradient: AppColors.darkGradient,
      bubbleColor: AppColors.accent.withValues(alpha: 0.28),
      bubbleSize: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      style: AppTypography.manrope(
                        12,
                        FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Carte L\'Atelier',
                      style: AppTypography.sora(
                        15,
                        FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: 'Palier ${tier.label}',
                color: AppColors.mint,
                background: AppColors.accent.withValues(alpha: 0.35),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${client.loyaltyPoints}',
                style: AppTypography.sora(
                  36,
                  FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'points',
                  style: AppTypography.manrope(
                    14,
                    FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                next == null ? 'Palier maximal atteint' : 'Prochain palier',
                style: AppTypography.manrope(
                  11,
                  FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              if (next != null)
                Text(
                  '${next.threshold} pts',
                  style: AppTypography.manrope(
                    11,
                    FontWeight.w700,
                    color: AppColors.mint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          AppProgressBar(
            value: progress,
            background: Colors.white24,
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.points,
    this.onRedeem,
  });

  final LoyaltyReward reward;
  final int points;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    final unlocked = reward.isUnlockedAt(points);

    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shadow: unlocked,
        child: Row(
          children: [
            AppIconTile(
              icon: unlocked ? Icons.redeem_rounded : Icons.lock_outline_rounded,
              color: unlocked ? AppColors.primary : AppColors.textFaint,
              background:
                  unlocked ? AppColors.tintGreen : AppColors.surfaceMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.name, style: AppTypography.rowTitleStrong),
                  const SizedBox(height: 1),
                  Text(
                    '${reward.pointsCost} points',
                    style: AppTypography.rowSubtitle,
                  ),
                ],
              ),
            ),
            if (unlocked)
              AppPillButton(label: 'Échanger', onTap: onRedeem)
            else
              Text(
                'Bientôt',
                style: AppTypography.manrope(
                  11.5,
                  FontWeight.w600,
                  color: AppColors.textFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
