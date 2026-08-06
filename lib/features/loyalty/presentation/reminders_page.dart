import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/loyalty_campaign.dart';
import 'loyalty_providers.dart';

/// 9.3 — Rappels automatiques par SMS et WhatsApp.
class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  static const routeName = '/loyalty/reminders';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(reminderStatsProvider).valueOrNull;
    final rules = ref.watch(reminderRulesProvider);

    return AppScreen(
      title: 'Rappels auto',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: 'Envoyés (mois)',
                  value: '${stats?.sentThisMonth ?? 0}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppStatTile(
                  label: 'Taux présence',
                  value: stats == null
                      ? '—'
                      : '${(stats.showUpRate * 100).round()} %',
                  tinted: true,
                ),
              ),
            ],
          ),
          const AppSectionTitle('Automatisations'),
          rules.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              compact: true,
              onRetry: () => ref.invalidate(reminderRulesProvider),
            ),
            data: (items) => items.isEmpty
                ? const AppEmptyState(
                    compact: true,
                    title: 'Aucune automatisation',
                    message:
                        'Activez les rappels de rendez-vous pour réduire les '
                        'absences.',
                    icon: Icons.notifications_active_outlined,
                  )
                : Column(
                    children: [
                      for (final rule in items) ...[
                        _ReminderCard(
                          rule: rule,
                          onToggle: (value) async {
                            await ref
                                .read(loyaltyRepositoryProvider)
                                .setReminderEnabled(
                                  ruleId: rule.id,
                                  isEnabled: value,
                                );
                            ref.invalidate(reminderRulesProvider);
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.rule, this.onToggle});

  final ReminderRule rule;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (rule.channel) {
      CampaignChannel.whatsapp => (
          Icons.chat_rounded,
          AppColors.violet,
          AppColors.tintViolet,
        ),
      CampaignChannel.both => (
          Icons.mark_email_unread_rounded,
          AppColors.primary,
          AppColors.tintGreen,
        ),
      CampaignChannel.sms => (
          Icons.sms_rounded,
          AppColors.primary,
          AppColors.tintGreen,
        ),
    };

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              AppIconTile(icon: icon, color: color, background: background),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.name, style: AppTypography.rowTitleStrong),
                    const SizedBox(height: 1),
                    Text(
                      rule.description ?? rule.channel.label,
                      style: AppTypography.rowSubtitle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AppToggle(value: rule.isEnabled, onChanged: onToggle),
            ],
          ),
          if (rule.messageTemplate?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            AppQuoteBlock('« ${rule.messageTemplate!} »'),
          ],
        ],
      ),
    );
  }
}
