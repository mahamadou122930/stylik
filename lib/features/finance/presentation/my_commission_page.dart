import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/finance_summary.dart';
import 'finance_providers.dart';

/// Commissions du membre connecté.
///
/// Pendant de `StylistReportPage`, qui montre toute l'équipe et reste réservé
/// au gérant : ici chacun ne voit que sa propre rémunération. La restriction
/// est aussi posée en base — `stylist_commissions` ne renvoie que la ligne de
/// l'appelant sans droit sur la finance.
class MyCommissionPage extends ConsumerWidget {
  const MyCommissionPage({super.key});

  static const routeName = '/finance/my-commission';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final commissions = ref.watch(commissionsProvider);
    final period = ref.watch(financePeriodProvider);

    return AppScreen(
      title: 'Mes commissions',
      largeTitle: true,
      header: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppFilterChips(
          items: [for (final value in FinancePeriod.values) value.label],
          selectedIndex: FinancePeriod.values.indexOf(period),
          onChanged: (index) => ref.read(financePeriodProvider.notifier).state =
              FinancePeriod.values[index],
        ),
      ),
      child: commissions.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(commissionsProvider),
        ),
        data: (rows) {
          // Aucune ligne quand la période n'a produit aucune vente : c'est un
          // zéro légitime, pas une erreur — d'où la fiche à zéro plutôt qu'un
          // état vide.
          final mine = rows
              .where((row) => row.stylistId == profile?.id)
              .fold<StylistCommission?>(null, (found, row) => found ?? row);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CommissionCard(
                commission: mine,
                rate: mine?.commissionRate ?? profile?.commissionRate ?? 0,
                periodLabel: period.label.toLowerCase(),
              ),
              const AppSectionTitle('Le détail'),
              AppListCard(
                children: [
                  AppListRow(
                    label: 'Prestations réalisées',
                    subtitle: 'Sur la période « ${period.label} »',
                    trailing: Text(
                      '${mine?.serviceCount ?? 0}',
                      style: AppTypography.sora(15, FontWeight.w800),
                    ),
                  ),
                  AppListRow(
                    label: 'Clients servis',
                    subtitle: 'Clients distincts',
                    trailing: Text(
                      '${mine?.clientCount ?? 0}',
                      style: AppTypography.sora(15, FontWeight.w800),
                    ),
                  ),
                  AppListRow(
                    label: 'Chiffre d\'affaires généré',
                    subtitle: 'Base de calcul de la commission',
                    trailing: Text(
                      Formatters.fcfa(mine?.revenueFcfa ?? 0),
                      style: AppTypography.sora(15, FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Les montants sont calculés sur les tickets encaissés et '
                'peuvent évoluer jusqu\'à la clôture de la période.',
                style: AppTypography.manrope(
                  12,
                  FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Montant dû sur la période, en évidence.
class _CommissionCard extends StatelessWidget {
  const _CommissionCard({
    required this.commission,
    required this.rate,
    required this.periodLabel,
  });

  final StylistCommission? commission;
  final double rate;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.tintGreenSoft,
      borderColor: AppColors.tintGreenBorder,
      shadow: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ma commission · $periodLabel',
            style: AppTypography.statLabel,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.fcfa(commission?.commissionFcfa ?? 0),
              maxLines: 1,
              style: AppTypography.sora(
                30,
                FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Taux appliqué : ${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1)} %',
            style: AppTypography.manrope(
              12.5,
              FontWeight.w600,
              color: AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}
