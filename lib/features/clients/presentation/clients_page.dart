import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../loyalty/domain/loyalty_campaign.dart';
import '../domain/client.dart';
import 'client_detail_page.dart';
import 'client_form_page.dart';
import 'clients_providers.dart';

/// 3.1 — Liste clients : recherche et index alphabétique.
class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});

  static const routeName = '/clients';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsListProvider);
    final grouped = ref.watch(clientsByLetterProvider);

    return AppScreen(
      title: 'Clients',
      largeTitle: true,
      showBack: false,
      action: AppIconButton(
        icon: Icons.add_rounded,
        filled: true,
        onTap: () => Navigator.of(context).pushNamed(ClientFormPage.routeName),
      ),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: AppSearchField(
          hint: 'Rechercher un client…',
          onChanged: (value) =>
              ref.read(clientSearchProvider.notifier).state = value,
        ),
      ),
      child: clients.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(clientsListProvider),
        ),
        data: (items) => items.isEmpty
            ? AppEmptyState(
                title: 'Aucun client',
                message: 'Créez une première fiche client.',
                icon: Icons.people_outline_rounded,
                actionLabel: 'Nouveau client',
                onAction: () =>
                    Navigator.of(context).pushNamed(ClientFormPage.routeName),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in grouped.entries) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        2,
                        entry.key == grouped.keys.first ? 6 : 16,
                        2,
                        8,
                      ),
                      child: Text(
                        entry.key,
                        style: AppTypography.sora(
                          12.5,
                          FontWeight.w700,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ),
                    AppListCard(
                      children: [
                        for (final client in entry.value)
                          ClientRow(
                            client: client,
                            onTap: () => Navigator.of(context).pushNamed(
                              ClientDetailPage.routeName,
                              arguments: client.id,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Ligne client : avatar, nom, activité, badge fidélité.
class ClientRow extends StatelessWidget {
  const ClientRow({super.key, required this.client, this.onTap});

  final Client client;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = client.isVip
        ? AppColors.violet
        : client.isLoyal
        ? AppColors.primary
        : AppColors.blue;

    final tier = LoyaltyTier.forPoints(client.loyaltyPoints);
    final tierColor = switch (tier) {
      LoyaltyTier.bronze => const Color(0xFF64748B),
      LoyaltyTier.silver => const Color(0xFF0284C7),
      LoyaltyTier.gold => const Color(0xFFD97706),
      LoyaltyTier.platinum => const Color(0xFF7C3AED),
    };
    final tierBg = switch (tier) {
      LoyaltyTier.bronze => const Color(0xFFF1F5F9),
      LoyaltyTier.silver => const Color(0xFFE0F2FE),
      LoyaltyTier.gold => const Color(0xFFFEF3C7),
      LoyaltyTier.platinum => const Color(0xFFF3E8FF),
    };

    return AppListRow(
      label: client.fullName,
      subtitle: '${client.activityLabel} · ${client.loyaltyPoints} pts',
      strong: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 11),
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          client.initials,
          style: AppTypography.sora(14, FontWeight.w700, color: accent),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBadge(
            label: tier.label,
            color: tierColor,
            background: tierBg,
            dense: true,
          ),
          const SizedBox(width: 6),
          const AppChevron(),
        ],
      ),
    );
  }
}
