import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/loyalty_campaign.dart';
import 'loyalty_providers.dart';

/// 9.2 — Promotions / offres : campagnes en cours et planifiées.
class PromotionsPage extends ConsumerWidget {
  const PromotionsPage({super.key});

  static const routeName = '/loyalty/promotions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotions = ref.watch(promotionsProvider);

    return AppScreen(
      title: 'Promotions',
      largeTitle: true,
      showBack: true,
      action: AppIconButton(
        icon: Icons.add_rounded,
        filled: true,
        onTap: () {
          // TODO(loyalty): formulaire de création d'une promotion.
        },
      ),
      child: promotions.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(promotionsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              title: 'Aucune promotion',
              message: 'Créez une offre pour remplir les heures creuses.',
              icon: Icons.local_offer_outlined,
            );
          }

          final running = items
              .where((promotion) => promotion.isActive && !promotion.isScheduled)
              .toList();
          final scheduled =
              items.where((promotion) => promotion.isScheduled).toList();

          Future<void> toggle(Promotion promotion, bool value) async {
            await ref.read(loyaltyRepositoryProvider).setPromotionActive(
                  promotionId: promotion.id,
                  isActive: value,
                );
            ref.invalidate(promotionsProvider);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (running.isNotEmpty) ...[
                const AppSectionLabel('En cours'),
                for (var i = 0; i < running.length; i++) ...[
                  if (i == 0)
                    _FeaturedPromotion(
                      promotion: running[i],
                      onToggle: (value) => toggle(running[i], value),
                    )
                  else
                    _PromotionRow(
                      promotion: running[i],
                      onToggle: (value) => toggle(running[i], value),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
              if (scheduled.isNotEmpty) ...[
                const AppSectionLabel(
                  'Planifiées',
                  padding: EdgeInsets.fromLTRB(2, 8, 2, 10),
                ),
                for (final promotion in scheduled) ...[
                  _PromotionRow(promotion: promotion, upcoming: true),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Promotion mise en avant, en carte à dégradé.
class _FeaturedPromotion extends StatelessWidget {
  const _FeaturedPromotion({required this.promotion, this.onToggle});

  final Promotion promotion;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    return AppGradientCard(
      padding: const EdgeInsets.all(18),
      bubbleAlignment: Alignment.bottomRight,
      bubbleSize: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBadge.onDark(label: 'Active'),
              const Spacer(),
              AppToggle(
                value: promotion.isActive,
                width: 36,
                onChanged: onToggle,
                activeColor: Colors.white.withValues(alpha: 0.9),
                thumbColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            promotion.name,
            style: AppTypography.sora(
              22,
              FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${promotion.description} · ${promotion.periodLabel}',
            style: AppTypography.manrope(
              13,
              FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _PromoMetric(
                value: '${promotion.usageCount}',
                label: 'utilisées',
              ),
              const SizedBox(width: 18),
              _PromoMetric(
                value: Formatters.fcfa(promotion.revenueFcfa),
                label: 'CA généré',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromoMetric extends StatelessWidget {
  const _PromoMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.sora(18, FontWeight.w800, color: Colors.white),
        ),
        Text(
          label,
          style: AppTypography.manrope(
            10.5,
            FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class _PromotionRow extends StatelessWidget {
  const _PromotionRow({
    required this.promotion,
    this.onToggle,
    this.upcoming = false,
  });

  final Promotion promotion;
  final ValueChanged<bool>? onToggle;
  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    final color = upcoming ? AppColors.amber : AppColors.violet;
    final background = upcoming ? AppColors.tintAmber : AppColors.tintViolet;

    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          AppIconTile(
            icon: upcoming
                ? Icons.event_available_rounded
                : Icons.auto_awesome_rounded,
            color: color,
            background: background,
            size: 44,
            radius: 13,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promotion.name,
                  style: AppTypography.sora(14.5, FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${promotion.description} · ${promotion.periodLabel}',
                  style: AppTypography.manrope(
                    12,
                    FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (upcoming)
            AppBadge(
              label: 'À venir',
              color: AppColors.amber,
              background: AppColors.tintAmber,
            )
          else
            AppToggle(
              value: promotion.isActive,
              width: 36,
              onChanged: onToggle,
            ),
        ],
      ),
    );
  }
}
