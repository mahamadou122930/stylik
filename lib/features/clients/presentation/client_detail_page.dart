import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../agenda/presentation/appointment_form_page.dart';
import '../../loyalty/domain/loyalty_campaign.dart';
import '../data/clients_repository.dart';
import '../domain/client.dart';
import 'client_form_page.dart';
import 'clients_providers.dart';

/// 3.2 — Fiche client : allergies, photos avant/après, préférences, historique.
class ClientDetailPage extends ConsumerWidget {
  const ClientDetailPage({super.key, required this.clientId});

  static const routeName = '/clients/detail';

  final String clientId;

  Future<void> _uploadPhoto(
    WidgetRef ref,
    Client client,
    File file, {
    required bool isBefore,
  }) async {
    await ref.read(clientsRepositoryProvider).uploadPhoto(
          client: client,
          file: file,
          isBefore: isBefore,
        );
    ref.invalidate(clientDetailProvider(client.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientDetailProvider(clientId));

    return AppScreen(
      title: 'Fiche client',
      action: AppIconButton(
        icon: Icons.edit_outlined,
        onTap: () => Navigator.of(context).pushNamed(ClientFormPage.routeName),
      ),
      footer: Row(
        children: [
          AppIconButton(
            icon: Icons.mail_outline_rounded,
            onTap: () {
              final c = client.valueOrNull;
              final name = c?.fullName ?? 'Client';
              SharePlus.instance.share(ShareParams(text: 'Bonjour $name, votre salon Stylik reste à votre service !'));
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Prendre RDV',
              icon: Icons.add_rounded,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppointmentFormPage.routeName),
            ),
          ),
        ],
      ),
      child: client.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(clientDetailProvider(clientId)),
        ),
        data: (data) => data == null
            ? const AppEmptyState(
                title: 'Client introuvable',
                icon: Icons.person_off_outlined,
              )
            : _ClientBody(
                client: data,
                onBeforePicked: (file) =>
                    _uploadPhoto(ref, data, file, isBefore: true),
                onAfterPicked: (file) =>
                    _uploadPhoto(ref, data, file, isBefore: false),
              ),
      ),
    );
  }
}

class _ClientBody extends ConsumerWidget {
  const _ClientBody({
    required this.client,
    required this.onBeforePicked,
    required this.onAfterPicked,
  });

  final Client client;
  final ValueChanged<File> onBeforePicked;
  final ValueChanged<File> onAfterPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(clientHistoryProvider(client.id));
    final historyList = history.valueOrNull ?? const [];

    final computedVisits = historyList.length;
    final computedSpent = historyList.fold<int>(0, (sum, v) => sum + v.amountFcfa);

    final displayVisits = client.visitCount > 0
        ? client.visitCount
        : (computedVisits > 0 ? computedVisits : 0);
    final displaySpent = client.totalSpentFcfa > 0
        ? client.totalSpentFcfa
        : (computedSpent > 0 ? computedSpent : 0);
    final displayPoints = client.loyaltyPoints > 0
        ? client.loyaltyPoints
        : (displaySpent / 1000).floor();

    final tier = LoyaltyTier.forPoints(displayPoints);
    final nextTier = tier.next;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 14),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  client.initials,
                  style: AppTypography.sora(
                    22,
                    FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      style: AppTypography.sora(
                        20,
                        FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppBadge(
                          label: '$displayPoints pts · Palier ${tier.label}',
                          color: tierColor,
                          background: tierBg,
                          dense: true,
                        ),
                        if (client.hasAllergies)
                          const AppBadge(
                            label: 'Allergie',
                            color: AppColors.dangerDeep,
                            background: AppColors.tintExpense,
                            dense: true,
                          ),
                        for (final tag in client.tags)
                          AppBadge(
                            label: tag,
                            color: AppColors.violet,
                            background: AppColors.tintViolet,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Carte Programme de Fidélité
        AppCard(
          radius: 16,
          color: AppColors.tintGreen,
          borderColor: AppColors.tintGreenBorder,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppIconTile(
                    icon: Icons.stars_rounded,
                    color: AppColors.primary,
                    background: Colors.white,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compte fidélité · Palier ${tier.label}',
                          style: AppTypography.manrope(12, FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$displayPoints points accumulés',
                          style: AppTypography.sora(17, FontWeight.w800, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (nextTier != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ((displayPoints - tier.threshold) / (nextTier.threshold - tier.threshold)).clamp(0.0, 1.0),
                    color: AppColors.primary,
                    backgroundColor: AppColors.tintGreenBorder,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Plus que ${nextTier.threshold - displayPoints} pts pour passer au palier ${nextTier.label} (${nextTier.threshold} pts)',
                  style: AppTypography.manrope(11.5, FontWeight.w500, color: AppColors.textSecondary),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  '🏆 Palier Maximal (Platine) atteint !',
                  style: AppTypography.manrope(12, FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (client.hasAllergies) ...[
          AppCard(
            radius: 14,
            shadow: false,
            color: AppColors.tintExpense,
            borderColor: AppColors.dangerBorder,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.dangerDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allergies & précautions',
                        style: AppTypography.sora(
                          12.5,
                          FontWeight.w700,
                          color: AppColors.dangerDeep,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        client.allergiesNotes!,
                        style: AppTypography.manrope(
                          11.5,
                          FontWeight.w500,
                          color: AppColors.dangerDarker,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        AppSplitMetrics(
          entries: [
            (value: '$displayVisits', label: 'Visites', color: null),
            (
              value: Formatters.fcfa(displaySpent),
              label: 'Total Achats',
              color: null,
            ),
            (
              value: '$displayPoints pts',
              label: 'Fidélité',
              color: AppColors.primary,
            ),
          ],
        ),

        const AppSectionTitle('Photos avant / après'),
        BeforeAfterSlots(
          beforeUrl: client.photoBeforeUrl,
          afterUrl: client.photoAfterUrl,
          onBeforePicked: onBeforePicked,
          onAfterPicked: onAfterPicked,
        ),
        if (client.preferences.isNotEmpty) ...[
          const AppSectionTitle('Préférences'),
          AppListCard(
            children: [
              for (final entry in client.preferences.entries)
                AppListRow(label: entry.key, value: '${entry.value}'),
            ],
          ),
        ],
        const AppSectionTitle('Historique des achats & prestations'),
        history.when(
          loading: () => const AppLoader(compact: true),
          error: (error, _) => AppErrorState(message: '$error', compact: true),
          data: (visits) => visits.isEmpty
              ? const AppEmptyState(
                  compact: true,
                  title: 'Aucun achat ni rendez-vous',
                  message: 'Les ventes en caisse et les RDV du client apparaîtront ici.',
                  icon: Icons.history_rounded,
                )
              : AppListCard(
                  children: [
                    for (final visit in visits) _VisitRow(visit: visit),
                  ],
                ),
        ),
      ],
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit});

  final ClientVisit visit;

  @override
  Widget build(BuildContext context) {
    final isTx = visit.isTransaction;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        children: [
          AppIconTile(
            icon: isTx ? Icons.receipt_long_rounded : Icons.calendar_today_rounded,
            color: isTx ? AppColors.primary : AppColors.blue,
            background: isTx ? AppColors.tintGreen : AppColors.tintBlue,
            size: 34,
            radius: 10,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.label,
                  style: AppTypography.manrope(13.5, FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${Formatters.dayMonth(visit.date)}${visit.stylistName != null ? ' · ${visit.stylistName}' : ''}',
                  style: AppTypography.rowSubtitle,
                ),
              ],
            ),
          ),
          Text(
            Formatters.fcfa(visit.amountFcfa),
            style: AppTypography.sora(
              13,
              FontWeight.w700,
              color: AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}
