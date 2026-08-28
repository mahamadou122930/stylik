import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/finance_summary.dart';
import '../../auth/presentation/auth_providers.dart';
import 'finance_providers.dart';
import 'period_header.dart';
import 'stylist_commission_detail_page.dart';

/// 8.2 — Rapport par coiffeur : CA généré et commission due.
class StylistReportPage extends ConsumerWidget {
  const StylistReportPage({super.key});

  static const routeName = '/finance/stylists';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);
    final anchor = ref.watch(financeAnchorProvider);
    // Tant que le profil n'est pas résolu — session en cours de restauration,
    // appareil hors ligne — le salon est inconnu et les providers rendent des
    // listes vides. Annoncer « Aucun coiffeur » serait alors un mensonge.
    final salonId = ref.watch(currentSalonIdProvider);
    final commissions = ref.watch(commissionsProvider);
    // Toute l'équipe, y compris qui n'a rien encaissé sur la période.
    final items = ref.watch(stylistReportProvider);
    // Déjà versé sur la même période que le CA et la commission.
    final paid = ref.watch(paidByStylistProvider);

    return AppScreen(
      title: 'Par coiffeur',
      // Même en-tête que Finance et Résultat net : le gérant qui suit une
      // journée veut aussi savoir qui l'a faite. Sans lui, l'écran restait
      // prisonnier de l'échelle choisie ailleurs.
      header: const Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: FinancePeriodHeader(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
            child: Text(
              // La période nommée — « Août » — plutôt que l'échelle
              // — « Mois » — qui n'indique pas laquelle on regarde.
              '${period.titleFor(anchor)} · CA généré et commission due',
              style: AppTypography.manrope(
                12.5,
                FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (salonId == null)
            const AppLoader()
          else
            commissions.when(
              loading: () => const AppLoader(),
              error: (error, _) => AppErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(commissionsProvider),
              ),
              data: (_) => items.isEmpty
                  ? const AppEmptyState(
                      title: 'Aucun coiffeur',
                      message:
                          'Ajoutez votre équipe pour suivre les '
                          'commissions.',
                      icon: LucideIcons.chartLine,
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          _StylistCard(
                            commission: items[i],
                            accent: AppColors
                                .chartSeries[i % AppColors.chartSeries.length],
                            paidFcfa: paid[items[i].stylistId] ?? 0,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _StylistCard extends StatelessWidget {
  const _StylistCard({
    required this.commission,
    required this.accent,
    required this.paidFcfa,
  });

  final StylistCommission commission;
  final Color accent;

  /// Déjà versé sur la période affichée.
  final int paidFcfa;

  /// Ce qu'il reste à régler au coiffeur.
  ///
  /// C'est le chiffre que le gérant vient chercher : la commission brute ne
  /// lui dit pas ce qu'il doit sortir de sa caisse aujourd'hui. Un versement
  /// dépassant la commission de la période — une avance, ou le règlement du
  /// mois précédent — ramène le reste à zéro plutôt qu'en négatif ; la
  /// colonne « Versé » reste là pour montrer l'écart.
  int get remainingFcfa => (commission.commissionFcfa - paidFcfa).clamp(
    0,
    commission.commissionFcfa,
  );

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(
        context,
      ).pushNamed(StylistCommissionDetailPage.routeName, arguments: commission),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  Formatters.initials(commission.stylistName),
                  style: AppTypography.sora(15, FontWeight.w700, color: accent),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commission.stylistName,
                      style: AppTypography.manrope(15, FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      [
                        if (commission.speciality?.isNotEmpty ?? false)
                          commission.speciality!,
                        '${commission.clientCount} client(s)',
                        // Le nombre de prestations n'est rappelé que si le
                        // compte clients est à zéro malgré des ventes : il
                        // lève alors l'ambiguïté sans alourdir la ligne.
                        if (commission.clientCount == 0 &&
                            commission.serviceCount > 0)
                          '${commission.serviceCount} prestation(s)',
                      ].join(' · '),
                      style: AppTypography.rowSubtitle,
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: '${commission.commissionRate.toStringAsFixed(0)} %',
                color: accent,
                background: accent.withValues(alpha: 0.14),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppSplitMetrics(
            entries: [
              (
                value: Formatters.fcfa(commission.revenueFcfa),
                label: 'CA généré',
                color: null,
              ),
              (
                value: Formatters.fcfa(remainingFcfa),
                label: 'Reste dû',
                color: AppColors.primary,
              ),
              // Ce qui a réellement quitté la caisse. Additionné au reste dû,
              // il redonne la commission brute de la période.
              (value: Formatters.fcfa(paidFcfa), label: 'Versé', color: null),
            ],
          ),
        ],
      ),
    );
  }
}
