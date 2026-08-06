import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/clients_repository.dart';
import '../domain/client.dart';
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
        onTap: () {
          // TODO(clients): édition de la fiche client.
        },
      ),
      footer: Row(
        children: [
          AppIconButton(
            icon: Icons.mail_outline_rounded,
            onTap: () {
              // TODO(clients): envoyer un message au client.
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Prendre RDV',
              icon: Icons.add_rounded,
              onPressed: () {
                // TODO(agenda): pré-remplir un nouveau RDV pour ce client.
              },
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
                        if (client.isLoyal)
                          const AppBadge(
                            label: 'Fidèle',
                            color: AppColors.primary,
                            background: AppColors.tintGreen,
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
            (value: '${client.visitCount}', label: 'Visites', color: null),
            (
              value: Formatters.fcfa(client.totalSpentFcfa),
              label: 'Total',
              color: null,
            ),
            (
              value: client.daysSinceLastVisit == null
                  ? '—'
                  : '${client.daysSinceLastVisit} j',
              label: 'Dernière',
              color: null,
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
        const AppSectionTitle('Historique'),
        history.when(
          loading: () => const AppLoader(compact: true),
          error: (error, _) => AppErrorState(message: '$error', compact: true),
          data: (visits) => visits.isEmpty
              ? const AppEmptyState(
                  compact: true,
                  title: 'Aucun passage',
                  message: 'Les rendez-vous passés apparaîtront ici.',
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              Formatters.dayMonth(visit.date),
              style: AppTypography.sora(12.5, FontWeight.w700),
            ),
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
                if (visit.stylistName != null)
                  Text(visit.stylistName!, style: AppTypography.rowSubtitle),
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
