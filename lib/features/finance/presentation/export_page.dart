import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import 'finance_providers.dart';

/// 8.5 — Export comptable : période, format et envoi.
class ExportPage extends ConsumerWidget {
  const ExportPage({super.key});

  static const routeName = '/finance/export';

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final salonId = ref.read(currentSalonIdProvider);
    if (salonId == null) return;

    final range = ref.read(exportPeriodProvider).range;
    final csv = await ref.read(financeRepositoryProvider).exportCsv(
          salonId: salonId,
          from: range.from,
          to: range.to,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export généré (${csv.split('\n').length - 1} lignes)'),
      ),
    );
  }

  Future<void> _sendToAccountant(BuildContext context, WidgetRef ref) async {
    final salonId = ref.read(currentSalonIdProvider);
    if (salonId == null) return;

    final range = ref.read(exportPeriodProvider).range;
    await ref.read(financeRepositoryProvider).sendExportToAccountant(
          salonId: salonId,
          from: range.from,
          to: range.to,
          format: ref.read(exportFormatProvider).value,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export envoyé au comptable')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(exportPeriodProvider);
    final format = ref.watch(exportFormatProvider);
    final summary = ref.watch(exportSummaryProvider).valueOrNull;

    return AppScreen(
      title: 'Export comptable',
      footer: Row(
        children: [
          Expanded(
            child: AppButton.outline(
              label: 'Télécharger',
              icon: Icons.download_rounded,
              onPressed: () => _download(context, ref),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Au comptable',
              icon: Icons.mail_outline_rounded,
              onPressed: () => _sendToAccountant(context, ref),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
            child: Text(
              'Période',
              style: AppTypography.sora(
                12.5,
                FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
          ),
          AppSegmented(
            padding: const EdgeInsets.only(bottom: 18),
            items: [for (final value in ExportPeriod.values) value.label],
            selectedIndex: ExportPeriod.values.indexOf(period),
            onChanged: (index) => ref.read(exportPeriodProvider.notifier).state =
                ExportPeriod.values[index],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              'Format',
              style: AppTypography.sora(
                12.5,
                FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
          ),
          for (final value in ExportFormat.values) ...[
            _FormatOption(
              format: value,
              selected: value == format,
              onTap: () =>
                  ref.read(exportFormatProvider.notifier).state = value,
            ),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 9),
          AppListCard(
            children: [
              AppListRow(
                label: 'Recettes ${period.label.toLowerCase()}',
                value: Formatters.fcfa(summary?.revenue ?? 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              AppListRow(
                label: 'Charges ${period.label.toLowerCase()}',
                value: '− ${Formatters.fcfa(summary?.expenses ?? 0)}',
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Résultat net',
                        style: AppTypography.manrope(13.5, FontWeight.w700),
                      ),
                    ),
                    Text(
                      Formatters.fcfa(
                        (summary?.revenue ?? 0) - (summary?.expenses ?? 0),
                      ),
                      style: AppTypography.sora(
                        15,
                        FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final ExportFormat format;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPdf = format == ExportFormat.pdf;

    return AppCard(
      onTap: onTap,
      radius: 14,
      shadow: false,
      color: selected ? AppColors.tintGreenSoft : AppColors.surface,
      borderColor: selected ? AppColors.accent : AppColors.border,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isPdf ? AppColors.tintExpense : AppColors.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isPdf
                  ? Icons.picture_as_pdf_rounded
                  : Icons.table_chart_outlined,
              size: 19,
              color: isPdf ? AppColors.dangerDeep : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  format.label,
                  style: AppTypography.sora(14, FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(format.description, style: AppTypography.rowSubtitle),
              ],
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.accent : Colors.transparent,
              border: selected
                  ? null
                  : Border.all(color: AppColors.borderStrong, width: 2),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}
